//
//  NotchSystemUsageView.swift
//  boringNotch
//

import SwiftUI
import Defaults

struct NotchSystemUsageView: View {
    @ObservedObject var usage = SystemUsageManager.shared
    @Default(.enableSystemUsage) var enabled

    var body: some View {
        Group {
            if !enabled {
                VStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("System Usage Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        UsageGraphCard(
                            title: "CPU / GPU",
                            icon: "cpu.fill",
                            leftLabel: "CPU \(usage.cpuString)",
                            rightLabel: "GPU \(usage.gpuString)",
                            leftColor: .blue,
                            rightColor: .purple,
                            leftHistory: usage.cpuHistory,
                            rightHistory: usage.gpuHistory,
                            normalizeToHundred: true
                        )
                        UsageGraphCard(
                            title: "Network",
                            icon: "network",
                            leftLabel: "↓ \(usage.downloadString)",
                            rightLabel: "↑ \(usage.uploadString)",
                            leftColor: .orange,
                            rightColor: .cyan,
                            leftHistory: usage.networkDownloadHistory,
                            rightHistory: usage.networkUploadHistory,
                            normalizeToHundred: false
                        )
                    }
                    HStack(spacing: 6) {
                        UsageValueCard(title: "Memory", icon: "memorychip.fill", value: usage.memoryString, color: .green)
                        UsageValueCard(title: "Disk", icon: "internaldrive.fill", value: usage.diskString, color: .yellow)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if enabled {
                SystemUsageManager.shared.startMonitoring()
            }
        }
        .onDisappear {
            SystemUsageManager.shared.stopMonitoring()
        }
        .onChange(of: enabled) { _, newValue in
            if newValue {
                SystemUsageManager.shared.startMonitoring()
            } else {
                SystemUsageManager.shared.stopMonitoring()
            }
        }
    }
}

// MARK: - Graph Card

struct UsageGraphCard: View {
    let title: String
    let icon: String
    let leftLabel: String
    let rightLabel: String
    let leftColor: Color
    let rightColor: Color
    let leftHistory: [Double]
    let rightHistory: [Double]
    var normalizeToHundred: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(leftColor)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.7))
            }
            HStack(spacing: 6) {
                Text(leftLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(leftColor)
                Text(rightLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(rightColor)
            }
            DualLineGraph(
                leftData: leftHistory,
                rightData: rightHistory,
                leftColor: leftColor,
                rightColor: rightColor,
                normalizeToHundred: normalizeToHundred
            )
            .frame(height: 40)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Value Card

struct UsageValueCard: View {
    let title: String
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dual Line Graph

struct DualLineGraph: View {
    let leftData: [Double]
    let rightData: [Double]
    let leftColor: Color
    let rightColor: Color
    var normalizeToHundred: Bool

    var body: some View {
        GeometryReader { geo in
            let maxVal: Double = normalizeToHundred
                ? 100.0
                : max(leftData.max() ?? 1, rightData.max() ?? 1, 0.001)
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                lineFill(data: leftData, maxVal: maxVal, w: w, h: h, color: leftColor)
                linePath(data: leftData, maxVal: maxVal, w: w, h: h, color: leftColor)
                lineFill(data: rightData, maxVal: maxVal, w: w, h: h, color: rightColor)
                linePath(data: rightData, maxVal: maxVal, w: w, h: h, color: rightColor)
            }
        }
    }

    private func linePath(data: [Double], maxVal: Double, w: CGFloat, h: CGFloat, color: Color) -> some View {
        Path { path in
            guard data.count > 1 else { return }
            let step = w / CGFloat(data.count - 1)
            for (i, v) in data.enumerated() {
                let x = CGFloat(i) * step
                let y = h * (1 - CGFloat(v / maxVal))
                i == 0 ? path.move(to: .init(x: x, y: y)) : path.addLine(to: .init(x: x, y: y))
            }
        }
        .stroke(color, lineWidth: 1.5)
    }

    private func lineFill(data: [Double], maxVal: Double, w: CGFloat, h: CGFloat, color: Color) -> some View {
        Path { path in
            guard data.count > 1 else { return }
            let step = w / CGFloat(data.count - 1)
            path.move(to: .init(x: 0, y: h))
            for (i, v) in data.enumerated() {
                path.addLine(to: .init(x: CGFloat(i) * step, y: h * (1 - CGFloat(v / maxVal))))
            }
            path.addLine(to: .init(x: w, y: h))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [color.opacity(0.25), color.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
