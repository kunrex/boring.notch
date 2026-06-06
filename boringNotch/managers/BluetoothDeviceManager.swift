//
//  BluetoothDeviceManager.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import Foundation
import IOBluetooth


/// Monitors Bluetooth activities on the device
/// - Note: This class uses the IOBluetooth framework to monitor battery status
class BluetoothDeviceManager {

    static let shared = BluetoothDeviceManager()

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    
    private var observers: [(BluetoothEvent) -> Void] = []
    private let notificationQueueActor = NotificationQueue<BluetoothEvent>()

    enum BluetoothEvent {
        case deviceConnected(name: String, address: String)
        case deviceDisconnected(name: String, address: String)
    }

    private init() {
        startMonitoring()
    }

    /// Starts monitoring Bluetooth live activity
    private func startMonitoring() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )

        // Register disconnect for any already-connected paired devices
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in paired where device.isConnected() {
            registerDisconnect(for: device)
        }
    }

    /// Registers a Bluetooth diconnection
    private func registerDisconnect(for device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        guard disconnectNotifications[address] == nil else { return }
        let note = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
        if let note = note {
            disconnectNotifications[address] = note
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        registerDisconnect(for: device)
        let name = device.name ?? device.addressString ?? "Unknown Device"
        let address = device.addressString ?? ""
        enqueueNotification(.deviceConnected(name: name, address: address))
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        disconnectNotifications.removeValue(forKey: address)
        let name = device.name ?? device.addressString ?? "Unknown Device"
        enqueueNotification(.deviceDisconnected(name: name, address: address))
    }

    /// Enqueues a notification to be processed using the concurrency-based queue actor.
    private func enqueueNotification(_ event: BluetoothEvent) {
        Task { @MainActor in
            await notificationQueueActor.enqueue(event) { [weak self] ev in
                self?.notifyObservers(event: ev)
            }
        }
    }

    private func notifyObservers(event: BluetoothEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for observer in self.observers {
                observer(event)
            }
        }
    }

    
    /// Adds an observer to listen to battery changes
    /// - Parameter observer: The observer closure to be called on battery events
    /// - Returns: The ID of the observer for later removal
    func addObserver(_ observer: @escaping (BluetoothEvent) -> Void) -> Int {
        observers.append(observer)
        return observers.count - 1
    }

    /// Removes an observer by its ID
    /// - Parameter id: The ID of the observer to be removed
    func removeObserver(byId id: Int) {
        guard id >= 0 && id < observers.count else { return }
        observers.remove(at: id)
    }

    deinit {
        connectNotification?.unregister()
        for note in disconnectNotifications.values {
            note.unregister()
        }
    }
}
