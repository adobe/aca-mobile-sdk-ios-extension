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

/// Accumulates events in memory and dispatches on flush.
/// Used by BatchCoordinator for batching. Disk persistence handled separately.
class DirectHitProcessor: HitProcessing {

    // MARK: - Types

    typealias ProcessingCallback = ([Event]) -> Void

    // MARK: - Properties

    private let type: BatchHitType
    private var accumulatedEvents: [Event] = []
    private var accumulatedEventIds: Set<String> = []
    private var processingCallback: ProcessingCallback?
    private let queue = DispatchQueue(label: "com.adobe.contentanalytics.hitprocessor", qos: .utility)

    // MARK: - Initialization

    init(type: BatchHitType) {
        self.type = type
    }

    // MARK: - Configuration

    func setCallback(_ callback: @escaping ProcessingCallback) {
        queue.sync { [weak self] in
            self?.processingCallback = callback
        }
    }

    // MARK: - HitProcessing Protocol

    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return 0  // Edge handles retries
    }

    /// Process hit from disk during crash recovery.
    /// Accumulates event in memory if not already present.
    /// Returns true to remove from disk (we'll clear disk after dispatch).
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let eventData = decodeEvent(from: entity) else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Failed to decode event | ID: \(entity.uniqueIdentifier)")
            completion(true)  // Remove corrupted data
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                completion(true)
                return
            }

            let eventId = eventData.event.id.uuidString

            // Accumulate for crash recovery if not already in memory
            if !self.accumulatedEventIds.contains(eventId) {
                self.accumulatedEvents.append(eventData.event)
                self.accumulatedEventIds.insert(eventId)
                Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Recovered event from disk | Type: \(self.type) | ID: \(eventId)")
            }

            // Return true to clear from disk - we've accumulated it in memory
            completion(true)
        }
    }

    // MARK: - Event Processing

    func accumulateEvent(_ event: Event) {
        queue.sync { [weak self] in
            guard let self = self else { return }
            self.accumulatedEvents.append(event)
            self.accumulatedEventIds.insert(event.id.uuidString)
        }
    }

    func processAccumulatedEvents() -> [Event] {
        var eventsToProcess: [Event] = []
        var callback: ProcessingCallback?

        queue.sync { [weak self] in
            guard let self = self, !self.accumulatedEvents.isEmpty else {
                return
            }

            eventsToProcess = self.accumulatedEvents
            self.accumulatedEvents.removeAll()
            self.accumulatedEventIds.removeAll()
            callback = self.processingCallback

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Processing \(eventsToProcess.count) \(self.type) events")
        }

        if !eventsToProcess.isEmpty {
            callback?(eventsToProcess)
        }

        return eventsToProcess
    }

    func clear() {
        queue.async { [weak self] in
            self?.accumulatedEvents.removeAll()
            self?.accumulatedEventIds.removeAll()
        }
    }

    // MARK: - Private Decoding

    private struct DecodedEventData {
        let event: Event
        let type: String
    }

    private struct EventWrapper: Codable {
        let event: Event
        let type: String
    }

    private func decodeEvent(from entity: DataEntity) -> DecodedEventData? {
        guard let data = entity.data,
              let wrapper = try? JSONDecoder().decode(EventWrapper.self, from: data) else {
            return nil
        }

        return DecodedEventData(event: wrapper.event, type: wrapper.type)
    }
}
