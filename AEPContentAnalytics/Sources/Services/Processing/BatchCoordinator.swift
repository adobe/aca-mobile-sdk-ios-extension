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

/// Unified coordinator for batching, persistence, and event processing
///
/// This class consolidates three responsibilities into a single, cohesive component:
/// 1. **Batching Logic**: Tracks event counts and timing to determine when to flush
/// 2. **Persistence**: Writes events to disk immediately for crash recovery
/// 3. **Processing Coordination**: Reads persisted events and dispatches to orchestrator
///
/// Architecture Benefits:
/// - Single source of truth for batch state (no duplicate buffers)
/// - Clear responsibility boundaries
/// - Simpler state management
/// - Easier to test and maintain
class BatchCoordinator: BatchCoordinating {

    // MARK: - Internal Types

    /// Callback type for when asset events are ready to be processed
    typealias AssetProcessingCallback = ([Event]) -> Void

    /// Callback type for when experience events are ready to be processed
    typealias ExperienceProcessingCallback = ([Event]) -> Void

    // MARK: - Dependencies

    /// Persistent queue for asset events (crash recovery)
    private let assetHitQueue: PersistentHitQueue

    /// Persistent queue for experience events (crash recovery)
    private let experienceHitQueue: PersistentHitQueue

    /// Hit processor for reading persisted asset events
    private let assetHitProcessor: DirectHitProcessor

    /// Hit processor for reading persisted experience events
    private let experienceHitProcessor: DirectHitProcessor

    /// State manager for configuration access
    private let state: ContentAnalyticsStateManager

    // MARK: - Batching State

    /// Current batching configuration
    private var configuration: BatchingConfiguration

    /// Count of asset events in current batch
    private var assetEventCount: Int = 0

    /// Count of experience events in current batch
    private var experienceEventCount: Int = 0

    /// Time when first event was added to current batch
    private var firstTrackingTime: Date?

    /// Timer for automatic batch flushing
    private var batchTimer: Timer?

    // MARK: - Processing Callbacks

    /// Callback to execute when asset events should be processed
    private var assetProcessingCallback: AssetProcessingCallback

    /// Callback to execute when experience events should be processed
    private var experienceProcessingCallback: ExperienceProcessingCallback

    // MARK: - Thread Safety

    /// Serial queue for thread-safe batch operations
    private let batchQueue = DispatchQueue(label: "com.adobe.contentanalytics.batchcoordinator", qos: .utility)

    // MARK: - Initialization

    /// Initialize the batch coordinator with data queues and default configuration
    /// Callbacks should be set after initialization via setCallbacks()
    /// Configuration can be updated dynamically via updateConfiguration()
    /// - Parameters:
    ///   - assetDataQueue: Data queue for asset event persistence
    ///   - experienceDataQueue: Data queue for experience event persistence
    ///   - state: State manager for accessing configuration
    init(
        assetDataQueue: DataQueue,
        experienceDataQueue: DataQueue,
        state: ContentAnalyticsStateManager
    ) {
        self.configuration = .default
        self.state = state

        // Initialize hit processors (accumulate events from disk for batching)
        self.assetHitProcessor = DirectHitProcessor(type: .asset)
        self.experienceHitProcessor = DirectHitProcessor(type: .experience)

        // Create persistent queues with our hit processors
        self.assetHitQueue = PersistentHitQueue(dataQueue: assetDataQueue, processor: assetHitProcessor)
        self.experienceHitQueue = PersistentHitQueue(dataQueue: experienceDataQueue, processor: experienceHitProcessor)

        // Initialize with no-op callbacks - real callbacks set via setCallbacks() after orchestrator is created
        self.assetProcessingCallback = { _ in }
        self.experienceProcessingCallback = { _ in }

        // Start queue processing (reads persisted events into memory for batching + crash recovery)
        self.assetHitQueue.beginProcessing()
        self.experienceHitQueue.beginProcessing()

        Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "BatchCoordinator initialized")
    }

    deinit {
        flush()
        batchTimer?.invalidate()
    }

    // MARK: - Public API

    /// Add a single asset tracking event to the batch
    /// - Parameter event: Asset tracking event to process
    func addAssetEvent(_ event: Event) {
        batchQueue.async { [weak self] in
            self?.handleAssetEvent(event)
        }
    }

    /// Add a single experience tracking event to the batch
    /// - Parameter event: Experience tracking event to process
    func addExperienceEvent(_ event: Event) {
        batchQueue.async { [weak self] in
            self?.handleExperienceEvent(event)
        }
    }

    /// Update the batch coordinator configuration dynamically
    /// - Parameter newConfiguration: The new batching configuration to apply
    func updateConfiguration(_ newConfiguration: BatchingConfiguration) {
        batchQueue.async { [weak self] in
            self?.performConfigurationUpdate(newConfiguration)
        }
    }

    /// Manually flush all pending requests
    func flush() {
        batchQueue.async { [weak self] in
            self?.performFlush()
        }
    }

    /// Clear pending batch without sending (e.g., on identity reset)
    func clear() {
        batchQueue.async { [weak self] in
            guard let self = self else { return }
            let assetCount = self.assetEventCount
            let experienceCount = self.experienceEventCount

            self.assetEventCount = 0
            self.experienceEventCount = 0
            self.firstTrackingTime = nil
            self.batchTimer?.invalidate()
            self.batchTimer = nil

            // Also clear persisted events
            self.assetHitProcessor.clear()
            self.experienceHitProcessor.clear()

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Cleared \(assetCount) asset events and \(experienceCount) experience events without sending")
        }
    }

    /// Get current batch status for monitoring
    func getBatchStatus() -> (assetCount: Int, experienceCount: Int) {
        return batchQueue.sync {
            return (assetEventCount, experienceEventCount)
        }
    }

    /// Set callbacks after initialization (used by factory to wire up orchestrator)
    /// - Parameters:
    ///   - assetCallback: Callback for asset event processing
    ///   - experienceCallback: Callback for experience event processing
    func setCallbacks(
        assetCallback: @escaping AssetProcessingCallback,
        experienceCallback: @escaping ExperienceProcessingCallback
    ) {
        batchQueue.async { [weak self] in
            guard let self = self else { return }
            self.assetProcessingCallback = assetCallback
            self.experienceProcessingCallback = experienceCallback

            // Wire up hit processors to callbacks
            self.assetHitProcessor.setCallback { [weak self] events in
                self?.assetProcessingCallback(events)
            }

            self.experienceHitProcessor.setCallback { [weak self] events in
                self?.experienceProcessingCallback(events)
            }

            Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Orchestrator callbacks configured")
        }
    }

    // MARK: - Private Event Handling

    /// Handle asset event: persist and track for batching
    private func handleAssetEvent(_ event: Event) {
        // 1. Accumulate immediately in memory for fast batching
        assetHitProcessor.accumulateEvent(event)

        // 2. Also persist to disk for crash recovery
        persistEventImmediately(event, to: assetHitQueue, type: .asset)

        // 3. Track count (batching trigger)
        assetEventCount += 1

        Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Asset event queued: \(assetEventCount)")

        // 4. Start timer if needed
        if firstTrackingTime == nil {
            firstTrackingTime = Date()
            scheduleBatchFlush()
        }

        // 5. Check flush triggers
        checkAndFlushIfNeeded()
    }

    /// Handle experience event: persist and track for batching
    private func handleExperienceEvent(_ event: Event) {
        // 1. Accumulate immediately in memory for fast batching
        experienceHitProcessor.accumulateEvent(event)

        // 2. Also persist to disk for crash recovery
        persistEventImmediately(event, to: experienceHitQueue, type: .experience)

        // 3. Track count (batching trigger)
        experienceEventCount += 1

        Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Experience event queued: \(experienceEventCount)")

        // 4. Start timer if needed
        if firstTrackingTime == nil {
            firstTrackingTime = Date()
            scheduleBatchFlush()
        }

        // 5. Check flush triggers
        checkAndFlushIfNeeded()
    }

    // MARK: - Batching Logic

    /// Check if the batch should be flushed based on size or time limits
    private func checkAndFlushIfNeeded() {
        // Check if we've reached the maximum batch size (count both assets and experiences)
        let totalCount = assetEventCount + experienceEventCount
        if totalCount >= configuration.maxBatchSize {
            performFlush()
            return
        }

        // Check if we've exceeded the maximum wait time
        if let firstTime = firstTrackingTime {
            let timeElapsed = Date().timeIntervalSince(firstTime)
            if timeElapsed >= configuration.maxWaitTime {
                performFlush()
                return
            }
        }
    }

    /// Perform configuration update with proper handling of mode changes
    private func performConfigurationUpdate(_ newConfiguration: BatchingConfiguration) {
        let oldConfiguration = configuration
        configuration = newConfiguration

        // Check if batch size limit changed and we need to flush
        let totalCount = assetEventCount + experienceEventCount
        if newConfiguration.maxBatchSize < oldConfiguration.maxBatchSize &&
           totalCount >= newConfiguration.maxBatchSize {
            performFlush()
        }

        // Update timer interval if it changed
        if newConfiguration.flushInterval != oldConfiguration.flushInterval &&
           batchTimer != nil {
            scheduleBatchFlush()
        }
    }

    /// Trigger batch processing - send accumulated events to orchestrator
    ///
    /// **Flow:**
    /// 1. Events persisted to disk (crash recovery)
    /// 2. PersistentHitQueue processes async → accumulates in DirectHitProcessor
    /// 3. Flush triggered → send accumulated events
    /// 4. PersistentHitQueue removes from disk after successful send
    private func performFlush() {
        guard assetEventCount > 0 || experienceEventCount > 0 else { return }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Batch flush: \(assetEventCount) assets, \(experienceEventCount) experiences")

        // Reset batch state
        assetEventCount = 0
        experienceEventCount = 0
        firstTrackingTime = nil

        DispatchQueue.main.async { [weak self] in
            self?.batchTimer?.invalidate()
            self?.batchTimer = nil
        }

        // Send accumulated events from DirectHitProcessor
        assetHitProcessor.processAccumulatedEvents()
        experienceHitProcessor.processAccumulatedEvents()
    }

    /// Schedule automatic batch flush timer
    private func scheduleBatchFlush() {
        let interval = configuration.flushInterval
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.batchTimer?.invalidate()
            self.batchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.flush()
            }
        }
    }

    // MARK: - Persistence

    /// Persist event to disk immediately for crash recovery
    private func persistEventImmediately(_ event: Event, to queue: PersistentHitQueue, type: BatchHitType) {
        let wrapper = EventWrapper(event: event, type: type)

        guard let data = try? JSONEncoder().encode(wrapper) else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Failed to encode event | Type: \(type)")
            return
        }

        let entity = DataEntity(
            uniqueIdentifier: event.id.uuidString,
            timestamp: event.timestamp,
            data: data
        )

        if queue.queue(entity: entity) {
            Log.trace(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Event persisted | Type: \(type) | ID: \(event.id.uuidString)")
        } else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.BATCH_PROCESSOR, "Failed to queue event | Type: \(type)")
        }
    }

    /// Wrapper for event with type metadata (Event is Codable)
    private struct EventWrapper: Codable {
        let event: Event
        let type: String

        init(event: Event, type: BatchHitType) {
            self.event = event
            self.type = type == .asset ? "asset" : "experience"
        }
    }
}
