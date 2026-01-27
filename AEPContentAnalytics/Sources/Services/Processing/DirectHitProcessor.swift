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

/// Internal processor that accumulates events from disk and dispatches them
///
/// This class is used exclusively by `BatchCoordinator` for reading persisted events.
/// It implements the `HitProcessing` protocol to integrate with `PersistentHitQueue`.
///
/// **Responsibilities:**
/// - Decode events from disk storage
/// - Accumulate events in memory temporarily
/// - Dispatch accumulated events via callback when triggered
///
/// **Lifecycle:**
/// 1. Created by `BatchCoordinator` during initialization
/// 2. Attached to `PersistentHitQueue` for automatic event reading
/// 3. `processHit()` called by queue for each persisted event
/// 4. `processAccumulatedEvents()` called by coordinator on flush
/// 5. Events dispatched to orchestrator via callback
class DirectHitProcessor: HitProcessing {

    // MARK: - Types

    /// Callback type for dispatching accumulated events
    typealias ProcessingCallback = ([Event]) -> Void

    // MARK: - Properties

    /// Type of events this processor handles (asset or experience)
    private let type: BatchHitType

    /// Accumulated events waiting to be dispatched
    private var accumulatedEvents: [Event] = []

    /// Callback to invoke when events are ready to be processed
    private var processingCallback: ProcessingCallback?

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.adobe.contentanalytics.hitprocessor", qos: .utility)

    // MARK: - Initialization

    /// Initialize the hit processor for a specific event type
    /// - Parameter type: The type of events this processor handles
    init(type: BatchHitType) {
        self.type = type
    }

    // MARK: - Configuration

    /// Set the callback to invoke when accumulated events are ready
    /// - Parameter callback: Callback that receives the array of events to process
    func setCallback(_ callback: @escaping ProcessingCallback) {
        queue.async { [weak self] in
            self?.processingCallback = callback
        }
    }

    // MARK: - HitProcessing Protocol

    /// Retry interval for failed hits (not used - Edge handles retries)
    /// - Parameter entity: The data entity
    /// - Returns: 0 (Edge network handles retries)
    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return 0  // Edge handles retries
    }

    /// Process hit from persistent queue (called by PersistentHitQueue)
    /// - Normal operation: Event already in memory, just mark as processed
    /// - Crash recovery: Event not in memory, accumulate from disk
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let eventData = decodeEvent(from: entity) else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Failed to decode event | ID: \(entity.uniqueIdentifier)")
            completion(true)
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            let eventId = eventData.event.id.uuidString
            let alreadyAccumulated = self.accumulatedEvents.contains { $0.id.uuidString == eventId }

            if !alreadyAccumulated {
                self.accumulatedEvents.append(eventData.event)
                Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Recovered \(self.type) event from disk | ID: \(eventId)")
            }
        }

        completion(true)  // Mark as processed (will be removed from disk)
    }

    // MARK: - Event Processing

    /// Add event to in-memory batch (also persisted to disk separately for crash recovery)
    func accumulateEvent(_ event: Event) {
        queue.sync { [weak self] in
            self?.accumulatedEvents.append(event)
        }
    }

    /// Process all accumulated events
    ///
    /// Called by `BatchCoordinator` when a batch flush is triggered.
    /// Dispatches all accumulated events via the callback and clears the buffer.
    func processAccumulatedEvents() {
        queue.async { [weak self] in
            guard let self = self, !self.accumulatedEvents.isEmpty else {
                return
            }

            let events = self.accumulatedEvents
            self.accumulatedEvents.removeAll()

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Processing \(events.count) \(self.type) events from batch")

            self.processingCallback?(events)
        }
    }

    /// Clear all accumulated events without processing
    ///
    /// Called when clearing the batch (e.g., on identity reset).
    func clear() {
        queue.async { [weak self] in
            self?.accumulatedEvents.removeAll()
        }
    }

    // MARK: - Private Decoding

    /// Decoded event data
    private struct DecodedEventData {
        let event: Event
        let type: String
    }

    /// Event wrapper for persistence (must match BatchCoordinator.EventWrapper)
    private struct EventWrapper: Codable {
        let event: Event
        let type: String
    }

    /// Decode an event from a data entity
    /// - Parameter entity: The data entity containing the persisted event
    /// - Returns: Decoded event data or nil if decoding fails
    private func decodeEvent(from entity: DataEntity) -> DecodedEventData? {
        guard let data = entity.data,
              let wrapper = try? JSONDecoder().decode(EventWrapper.self, from: data) else {
            return nil
        }

        return DecodedEventData(event: wrapper.event, type: wrapper.type)
    }
}
