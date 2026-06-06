//
//  BluetoothStatusViewModel.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import Defaults
import Foundation
import SwiftUI

/// A view model that monitors the Bluetooth live activity of the device
class BluetoothStatusViewModel: ObservableObject {

    static let shared = BluetoothStatusViewModel()

    enum EventType {
        case connected
        case disconnected
    }

    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Published private(set) var lastDeviceName: String = ""
    @Published private(set) var lastEventType: EventType = .connected

    var statusText: String {
        lastDeviceName.isEmpty ? "" : lastDeviceName
    }

    var eventLabel: String {
        switch lastEventType {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        }
    }

    private let manager = BluetoothDeviceManager.shared
    private var managerId: Int?

    
    /// Initializes the view model with a given BoringViewModel instance
    /// - Parameter vm: The BoringViewModel instance
    private init() {
        setupMonitor()
    }

    
    /// Sets up the monitor to observe Bluetooth live activity 
    private func setupMonitor() {
        managerId = manager.addObserver { [weak self] event in
            guard let self else { return }
            self.handleBluetoothEvent(event)
        }
    }

    /// Handles Bluetooh live activity and updates the corresponding properties
    /// - Parameter event: The Bluetooth event to handle
    private func handleBluetoothEvent(_ event: BluetoothDeviceManager.BluetoothEvent) {
        switch event {
        case .deviceConnected(let name, _):
            print("🔵 Bluetooth connected: \(name)")
            withAnimation {
                self.lastDeviceName = name
                self.lastEventType = .connected
            }
            notifyChange()

        case .deviceDisconnected(let name, _):
            print("🔵 Bluetooth disconnected: \(name)")
            withAnimation {
                self.lastDeviceName = name
                self.lastEventType = .disconnected
            }
            notifyChange()
        }
    }

    
    /// Notifies changes in the Bluetooth status with an optional delay
    private func notifyChange() {
        Task {
            coordinator.toggleExpandingView(status: true, type: .bluetooth)
        }
    }

    deinit {
        if let id = managerId {
            manager.removeObserver(byId: id)
        }
    }
}
