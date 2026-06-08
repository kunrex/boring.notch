//
//  SystemUsageManager.swift
//  boringNotch
//

import Foundation
import Combine
import Defaults
import SwiftUI
import IOKit
import IOKit.graphics
import Darwin
import AppKit

// MARK: - GPU Collection

private final class GPUInfoCollector {
    func averageUtilization() -> Double {
        let matching = IOServiceMatching(kIOAcceleratorClassName)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        var utilizations: [Double] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let utilization = readUtilization(from: service) {
                utilizations.append(utilization)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        guard !utilizations.isEmpty else { return 0 }
        return utilizations.reduce(0, +) / Double(utilizations.count)
    }

    private func readUtilization(from service: io_registry_entry_t) -> Double? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any] else { return nil }
        let stats = dict["PerformanceStatistics"] as? [String: Any] ?? [:]
        for key in ["Device Utilization %", "GPU Activity(%)"] {
            if let n = stats[key] as? NSNumber { return min(max(n.doubleValue, 0), 100) }
            if let v = stats[key] as? Double    { return min(max(v, 0), 100) }
            if let v = stats[key] as? Int       { return min(max(Double(v), 0), 100) }
        }
        return nil
    }
}

// MARK: - Manager

class SystemUsageManager: ObservableObject {
    static let shared = SystemUsageManager()

    @Published var isMonitoring: Bool = false

    // Current values
    @Published var cpuUsage: Double = 0
    @Published var gpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var networkDownload: Double = 0  // MB/s
    @Published var networkUpload: Double = 0    // MB/s
    @Published var diskUsage: Double = 0        // root disk used %

    // Rolling histories (30 points)
    @Published var cpuHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var networkDownloadHistory: [Double] = []
    @Published var networkUploadHistory: [Double] = []

    private let maxHistory = 30
    private var monitoringTimer: Timer?
    private var stopTimer: Timer?
    private var startTimer: Timer?

    private let hostPort: mach_port_t = mach_host_self()
    private let totalPhysicalMemory: UInt64 = {
        var stats = host_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let port = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(port, HOST_BASIC_INFO, $0, &count)
            }
        }
        mach_port_deallocate(mach_task_self_, port)
        return result == KERN_SUCCESS ? UInt64(stats.max_mem) : UInt64(ProcessInfo.processInfo.physicalMemory)
    }()

    private var previousCPULoadInfo: host_cpu_load_info?
    private var previousNetworkStats: (bytesIn: UInt64, bytesOut: UInt64) = (0, 0)
    private var previousTimestamp: Date = Date()

    private let gpuCollector = GPUInfoCollector()
    private var cancellables = Set<AnyCancellable>()

    private var lastNotchOpen: Bool = false
    private var lastViewIsStats: Bool = false

    private init() {
        cpuHistory = Array(repeating: 0, count: maxHistory)
        gpuHistory = Array(repeating: 0, count: maxHistory)
        networkDownloadHistory = Array(repeating: 0, count: maxHistory)
        networkUploadHistory = Array(repeating: 0, count: maxHistory)

        let baseline = getNetworkStats()
        previousNetworkStats = baseline
        previousTimestamp = Date()

        Defaults.publisher(.systemUsageUpdateInterval, options: [])
            .sink { [weak self] change in
                guard let self, self.isMonitoring else { return }
                DispatchQueue.main.async { self.scheduleTimer() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func updateMonitoringState(notchIsOpen: Bool, viewIsStats: Bool) {
        guard notchIsOpen != lastNotchOpen || viewIsStats != lastViewIsStats else { return }
        lastNotchOpen = notchIsOpen
        lastViewIsStats = viewIsStats

        startTimer?.invalidate()
        stopTimer?.invalidate()

        let shouldMonitor = notchIsOpen && viewIsStats && Defaults[.enableSystemUsage]

        if shouldMonitor {
            startTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.startMonitoring() }
            }
        } else {
            stopTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.stopMonitoring() }
            }
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        let baseline = getNetworkStats()
        previousNetworkStats = baseline
        previousTimestamp = Date()

        isMonitoring = true
        diskUsage = collectDiskUsage()
        scheduleTimer()
        Task { @MainActor in self.tick() }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        previousCPULoadInfo = nil
    }

    // MARK: - Private

    private func scheduleTimer() {
        monitoringTimer?.invalidate()
        let interval = max(0.5, min(Defaults[.systemUsageUpdateInterval], 60.0))
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    @MainActor
    private func tick() {
        let newCPU = collectCPU()
        let newGPU = gpuCollector.averageUtilization()
        let newMem = collectMemory()

        let now = Date()
        let delta = max(now.timeIntervalSince(previousTimestamp), 0.01)
        let netStats = getNetworkStats()
        let bytesDown = netStats.bytesIn >= previousNetworkStats.bytesIn ? netStats.bytesIn - previousNetworkStats.bytesIn : 0
        let bytesUp   = netStats.bytesOut >= previousNetworkStats.bytesOut ? netStats.bytesOut - previousNetworkStats.bytesOut : 0
        let dl = Double(bytesDown) / delta / 1_048_576
        let ul = Double(bytesUp)   / delta / 1_048_576
        previousNetworkStats = netStats
        previousTimestamp = now

        cpuUsage = newCPU
        gpuUsage = newGPU
        memoryUsage = newMem
        networkDownload = max(0, dl)
        networkUpload = max(0, ul)

        appendHistory(value: newCPU, to: &cpuHistory)
        appendHistory(value: newGPU, to: &gpuHistory)
        appendHistory(value: max(0, dl), to: &networkDownloadHistory)
        appendHistory(value: max(0, ul), to: &networkUploadHistory)
    }

    private func appendHistory(value: Double, to history: inout [Double]) {
        if history.count >= maxHistory { history.removeFirst() }
        history.append(value)
    }

    // MARK: CPU

    private func collectCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return cpuUsage }

        let usage: Double
        if let prev = previousCPULoadInfo {
            let userD   = Double(info.cpu_ticks.0 - prev.cpu_ticks.0)
            let sysD    = Double(info.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleD   = Double(info.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceD   = Double(info.cpu_ticks.3 - prev.cpu_ticks.3)
            let total   = userD + sysD + idleD + niceD
            usage = total > 0 ? min(max((userD + niceD + sysD) / total * 100, 0), 100) : cpuUsage
        } else {
            let total = Double(info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3)
            usage = total > 0 ? min(max(Double(info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.3) / total * 100, 0), 100) : 0
        }
        previousCPULoadInfo = info
        return usage
    }

    // MARK: Memory

    private func collectMemory() -> Double {
        var vmStats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS, totalPhysicalMemory > 0 else { return memoryUsage }

        let page = UInt64(vm_kernel_page_size)
        let active     = UInt64(vmStats.active_count) * page
        let inactive   = UInt64(vmStats.inactive_count) * page
        let speculative = UInt64(vmStats.speculative_count) * page
        let wired      = UInt64(vmStats.wire_count) * page
        let compressed = UInt64(vmStats.compressor_page_count) * page
        let purgeable  = UInt64(vmStats.purgeable_count) * page
        let external   = UInt64(vmStats.external_page_count) * page

        let usedWithoutCache = active + inactive + speculative + wired + compressed
        let cache = purgeable + external
        let used = usedWithoutCache > cache ? usedWithoutCache - cache : 0
        let clamped = min(used, totalPhysicalMemory)

        return min(100, max(0, Double(clamped) / Double(totalPhysicalMemory) * 100))
    }

    // MARK: Disk

    private func collectDiskUsage() -> Double {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity, total > 0,
              let free = values.volumeAvailableCapacityForImportantUsage else {
            return diskUsage
        }
        let used = Int64(total) - free
        return max(0, min(100, Double(used) / Double(total) * 100))
    }

    // MARK: Network

    private func getNetworkStats() -> (bytesIn: UInt64, bytesOut: UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddrs) }

        var ptr = ifaddrs
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard current.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard !name.hasPrefix("lo"), !name.hasPrefix("gif"), !name.hasPrefix("stf"),
                  !name.hasPrefix("awdl"), !name.hasPrefix("utun"), !name.hasPrefix("bridge") else { continue }
            if name.hasPrefix("en") {
                if let data = current.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalIn  += UInt64(data.pointee.ifi_ibytes)
                    totalOut += UInt64(data.pointee.ifi_obytes)
                }
            }
        }
        return (totalIn, totalOut)
    }

    // MARK: Formatted strings

    var cpuString: String { String(format: "%.0f%%", cpuUsage) }
    var gpuString: String { String(format: "%.0f%%", gpuUsage) }
    var memoryString: String { String(format: "%.0f%%", memoryUsage) }
    var diskString: String { String(format: "%.0f%%", diskUsage) }

    var downloadString: String { throughput(networkDownload) }
    var uploadString: String { throughput(networkUpload) }

    private func throughput(_ mbps: Double) -> String {
        if mbps >= 1 {
            return String(format: mbps >= 10 ? "%.1f MB/s" : "%.2f MB/s", mbps)
        }
        let kbps = mbps * 1024
        if kbps >= 1 {
            return String(format: kbps >= 10 ? "%.0f KB/s" : "%.1f KB/s", kbps)
        }
        return "0 B/s"
    }
}
