//
//  LockScreenManager.swift
//  boringNotch
// 
// Created by Kunal Kashyap on 07/07/2026.
//

import AppKit
import SwiftUI
import Defaults

class LockScreenManager: ObservableObject {
    static let shared = LockScreenManager()

    @Published var isLocked: Bool = false

    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?
    private var observers: [(Bool) -> Void] = []

    private init() {
        // Use closure-based observers for DistributedNotificationCenter and keep tokens for removal
        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.screenLocked()
                }
        }

        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] notification in
                Task { @MainActor in
                    self?.screenUnlocked()
                }
        }
    }

    deinit {
        if let observer = screenLockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockedObserver = nil
        }
        if let observer = screenUnlockedObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockedObserver = nil
        }
    }

    @MainActor
    private func screenLocked() {
        guard !self.isLocked else { return }
        self.isLocked = true

        self.notifyObservers()
        LockScreenMusicPanelManager.shared.showPanel()
    }

    @MainActor
    private func screenUnlocked() {
        guard self.isLocked else { return }
        self.isLocked = false

        self.notifyObservers()
        LockScreenMusicPanelManager.shared.hidePanel()
    }

    /// Adds an observer to listen to lock screen changes
    /// - Returns: The ID of the observer for later removal
    func addObserver(_ observer: @escaping (Bool) -> Void) -> Int {
        observers.append(observer)
        return observers.count - 1
    }
    
    /// Removes an observer by its ID
    /// - Parameter id: The ID of the observer to be removed
    func removeObserver(byId id: Int) {
        guard id >= 0 && id < observers.count else { return }
        observers.remove(at: id)
    }
        
    /// Notifies all observers of a lock screen change 
    private func notifyObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for observer in self.observers {
                observer(self.isLocked)
            }
        }
    }
}
