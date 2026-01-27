/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPCore
import AEPServices
import Foundation

/// Type of batch hit
enum BatchHitType: String, Codable {
    case asset
    case experience
}

/// Batch of events persisted to disk for crash recovery
/// Note: This struct is currently unused (we persist individual events)
/// but kept for potential future use
struct BatchHit: Codable {
    let hitType: BatchHitType
    let events: [SerializableEvent]
    let metrics: [String: InteractionMetrics]?  // Unified metrics for both asset and experience batches
    let timestamp: Date
    let attemptCount: Int

    init(
        hitType: BatchHitType,
        events: [Event],
        metrics: [String: InteractionMetrics]? = nil,
        timestamp: Date = Date(),
        attemptCount: Int = 0
    ) {
        self.hitType = hitType
        self.events = events.map { SerializableEvent(event: $0) }
        self.metrics = metrics
        self.timestamp = timestamp
        self.attemptCount = attemptCount
    }

    /// Creates a copy with incremented attempt count (for retry tracking)
    func incrementingAttempt() -> BatchHit {
        return BatchHit(
            hitType: hitType,
            events: events.map { $0.toEvent() },
            metrics: metrics,
            timestamp: timestamp,
            attemptCount: attemptCount + 1
        )
    }

    /// Convert to Event array
    func toEvents() -> [Event] {
        return events.map { $0.toEvent() }
    }
}

/// Serializable version of Event for Codable compliance
struct SerializableEvent: Codable {
    let name: String
    let type: String
    let source: String
    let data: [String: AnyCodable]?
    let timestamp: Date
    let id: String

    init(event: Event) {
        self.name = event.name
        self.type = event.type
        self.source = event.source
        self.data = event.data?.mapValues { AnyCodable($0) }
        self.timestamp = event.timestamp
        self.id = event.id.uuidString
    }

    func toEvent() -> Event {
        let eventData = data?.compactMapValues { $0.value }
        return Event(
            name: name,
            type: type,
            source: source,
            data: eventData
        )
    }
}
