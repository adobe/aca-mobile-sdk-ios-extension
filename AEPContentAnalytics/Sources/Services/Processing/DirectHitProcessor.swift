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

/// Reads persisted events from disk, accumulates in memory, and dispatches on flush.
/// Used by BatchCoordinator to integrate with PersistentHitQueue for crash recovery.
class DirectHitProcessor: HitProcessing {

    // MARK: - Types

    /// Callback type for dispatching accumulated events
    typealias ProcessingCallback = ([Event]) -> Void

    // MARK: - Properties

    /// Type of events this processor handles (asset or experience)
    private let type: BatchHitType

    /// Accumulated events waiting to be dispatched
    private var accumulatedEvents: [Event] = []

    /// Event IDs that have been dispatched to Edge (can be removed from disk)
    private var dispatchedEventIds: Set<String> = []

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

    /// Decode event from disk. Keep on disk unless already dispatched to Edge.
    /// Returns false to keep, true to remove.
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let eventData = decodeEvent(from: entity) else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Failed to decode event | ID: \(entity.uniqueIdentifier)")
            completion(true)  // Remove corrupted data
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            let eventId = eventData.event.id.uuidString

            // If already dispatched to Edge, remove from disk
            if self.dispatchedEventIds.contains(eventId) {
                Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Event dispatched, removing from disk | ID: \(eventId)")
                completion(true)  // Remove from disk
                return
            }

            // Otherwise, accumulate in memory but keep on disk until dispatched
            let alreadyAccumulated = self.accumulatedEvents.contains { $0.id.uuidString == eventId }

            if !alreadyAccumulated {
                self.accumulatedEvents.append(eventData.event)
                Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Event accumulated, keeping on disk | Type: \(self.type) | ID: \(eventId)")
            }

            completion(false)  // Keep on disk until dispatched to Edge
        }
    }

    // MARK: - Event Processing

    /// Add event to in-memory batch (also persisted to disk separately for crash recovery)
    func accumulateEvent(_ event: Event) {
        queue.sync { [weak self] in
            self?.accumulatedEvents.append(event)
        }
    }

    /// Dispatch all accumulated events via callback, clear buffer, and return events.
    func processAccumulatedEvents() -> [Event] {
        var eventsToProcess: [Event] = []

        queue.sync { [weak self] in
            guard let self = self, !self.accumulatedEvents.isEmpty else {
                return
            }

            eventsToProcess = self.accumulatedEvents
            self.accumulatedEvents.removeAll()

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Processing \(eventsToProcess.count) \(self.type) events from batch")
        }

        if !eventsToProcess.isEmpty {
            processingCallback?(eventsToProcess)
        }

        return eventsToProcess
    }

    /// Clear all accumulated events without processing
    ///
    /// Called when clearing the batch (e.g., on identity reset).
    func clear() {
        queue.async { [weak self] in
            self?.accumulatedEvents.removeAll()
            self?.dispatchedEventIds.removeAll()
        }
    }

    /// Track event IDs as dispatched. Next processHit() cycle will remove from disk.
    func markEventsAsDispatched(_ events: [Event]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            for event in events {
                self.dispatchedEventIds.insert(event.id.uuidString)
            }

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Marked \(events.count) \(self.type) events as dispatched")
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
