//
//  NotificationQueue.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 31/05/26.
//

import Foundation

/// Serializes and delivers events with a 1-second delay between each.
actor NotificationQueue<Event> {
    private var queue: [Event] = []
    private var processing = false

    func enqueue(_ event: Event, deliver: @MainActor @escaping (Event) -> Void) {
        queue.append(event)
        if !processing {
            processing = true
            Task { await process(deliver: deliver) }
        }
    }

    private func process(deliver: @MainActor @escaping (Event) -> Void) async {
        while !queue.isEmpty {
            let event = queue.removeFirst()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await deliver(event)
        }
        processing = false
    }
}
