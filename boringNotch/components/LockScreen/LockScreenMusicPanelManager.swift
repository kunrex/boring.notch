//
//  LockScreenMusicPanelManager.swift
//  boringNotch
// 
// Created by Kunal Kashyap on 07/07/2026.
//

import SwiftUI
import AppKit
import SkyLightWindow
import Defaults
import Combine

@MainActor
final class LockScreenPanelAnimator: ObservableObject {
    @Published var isPresented: Bool = false
}

@MainActor
class LockScreenMusicPanelManager {
    static let shared = LockScreenMusicPanelManager()

    private var panelWindow: NSWindow?
    private var hasDelegated = false
    private var hideTask: Task<Void, Never>?
    private let animator = LockScreenPanelAnimator()
    private var musicObserver: AnyCancellable?

    private init() {
        // Auto-hide or show if music activity changes when locked
        musicObserver = MusicManager.shared.$isPlayerIdle
            .receive(on: RunLoop.main)
            .sink { [weak self] idle in
                guard let self, LockScreenManager.shared.isLocked else { return }
                if idle { 
                    self.hidePanel() 
                } else {
                    self.showPanel()
                } 
            }
    }

    func showPanel() {
        guard Defaults[.enableLockScreenMediaWidget],
              !MusicManager.shared.isPlayerIdle,
              let screen = NSScreen.main else {
            hidePanel()
            return
        }

        let size = LockScreenMusicPanel.panelSize
        let sf = screen.frame
        let targetFrame = NSRect(
            x: sf.midX - size.width / 2,
            y: sf.midY - size.height - 40,
            width: size.width,
            height: size.height
        )

        let window: NSWindow
        if let existing = panelWindow {
            window = existing
        } else {
            let w = NSWindow(
                contentRect: targetFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            w.isMovable = false
            w.hasShadow = false
            panelWindow = w
            window = w
            hasDelegated = false
        }

        window.setFrame(targetFrame, display: true)
        hideTask?.cancel()
        animator.isPresented = false

        let hostingView = NSHostingView(rootView: LockScreenMusicPanel(animator: animator))
        hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(window)
            hasDelegated = true
        }

        window.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.animator.isPresented = true
        }
    }

    func hidePanel() {
        animator.isPresented = false
        hideTask?.cancel()
        guard let window = panelWindow else { return }
        hideTask = Task { [weak window] in
            try? await Task.sleep(for: .milliseconds(380))
            await MainActor.run {
                window?.orderOut(nil)
                window?.contentView = nil
            }
        }
    }
}
