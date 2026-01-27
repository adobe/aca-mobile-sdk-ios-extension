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

/// Callback type for updating shared state from the service
typealias SharedStateUpdateCallback = (String?) -> Void

/// Result of event processing operations.
enum ProcessingResult {
    case success
    case skipped(reason: String)
    case failure(ContentAnalyticsError)
}

/// Orchestrates content analytics event processing, batching, and delivery
class ContentAnalyticsOrchestrator {

    // MARK: - Event Property Extractors

    /// Extracts asset key from an event
    private static let assetKeyExtractor: (Event) -> String? = { $0.assetKey }

    /// Extracts experience key from an event
    private static let experienceKeyExtractor: (Event) -> String? = { $0.experienceKey }

    /// Extracts asset URL identifier from an event
    private static let assetIdentifierExtractor: (Event) -> String? = { $0.assetURL }

    /// Extracts experience ID identifier from an event
    private static let experienceIdentifierExtractor: (Event) -> String? = { $0.experienceId }

    /// Extracts asset extras from an event
    private static let assetExtrasExtractor: (Event) -> [String: Any]? = { $0.assetExtras }

    /// Extracts experience extras from an event
    private static let experienceExtrasExtractor: (Event) -> [String: Any]? = { $0.experienceExtras }

    // MARK: - Properties

    private let state: ContentAnalyticsStateManager
    private let eventDispatcher: ContentAnalyticsEventDispatcher
    private let privacyValidator: PrivacyValidator
    private let xdmEventBuilder: XDMEventBuilderProtocol
    private var featurizationHitQueue: PersistentHitQueue?
    private let batchCoordinator: BatchCoordinating?

    // MARK: - Initialization

    init(
        state: ContentAnalyticsStateManager,
        eventDispatcher: ContentAnalyticsEventDispatcher,
        privacyValidator: PrivacyValidator,
        xdmEventBuilder: XDMEventBuilderProtocol,
        featurizationHitQueue: PersistentHitQueue?,
        batchCoordinator: BatchCoordinating?
    ) {
        self.state = state
        self.eventDispatcher = eventDispatcher
        self.privacyValidator = privacyValidator
        self.xdmEventBuilder = xdmEventBuilder
        self.featurizationHitQueue = featurizationHitQueue
        self.batchCoordinator = batchCoordinator

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Orchestrator initialized with batch coordinator")
    }

    // MARK: - Public Methods

    /// Check if featurization queue is already initialized.
    /// Used by extension to avoid recreating the queue on every config change.
    func hasFeaturizationQueue() -> Bool {
        return featurizationHitQueue != nil
    }

    /// Initializes the featurization hit queue if not already created (lazy initialization)
    /// Only called once when valid configuration first becomes available
    /// - Parameter queue: The newly created featurization queue (or nil if config is invalid)
    func initializeFeaturizationQueueIfNeeded(queue: PersistentHitQueue?) {
        // Only set queue if it doesn't exist yet
        guard featurizationHitQueue == nil else {
            Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "Featurization queue already initialized - skipping")
            return
        }

        featurizationHitQueue = queue

        if featurizationHitQueue != nil {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "✅ Featurization queue initialized successfully")
        } else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "Featurization queue not yet available (waiting for valid configuration)")
        }
    }

    func processAssetEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void) {
        // Validate required fields
        guard event.assetURL != nil,
              event.interactionType != nil,
              event.assetKey != nil else {
            completion(.failure(.validationError("Missing required asset fields")))
            return
        }

        // Validate action is view or click
        if let action = event.interactionType,
           action != InteractionType.view && action != InteractionType.click {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "Asset event has invalid action: \(action)")
            completion(.failure(.validationError("Invalid action type: \(action)")))
            return
        }

        // Validate processing conditions
        if let error = validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Process the event
        processValidatedAssetEvent(event)
        completion(.success(()))
    }

    func processExperienceEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void) {
        // Validate required fields
        guard event.experienceId != nil,
              event.interactionType != nil else {
            completion(.failure(.validationError("Missing required experience fields")))
            return
        }

        // Validate action is definition, view, or click
        if let action = event.interactionType,
           action != InteractionType.definition && action != InteractionType.view && action != InteractionType.click {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "Experience event has invalid action: \(action)")
            completion(.failure(.validationError("Invalid action type: \(action)")))
            return
        }

        // Validate processing conditions
        if let error = validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Experience-specific validation
        guard state.configuration?.trackExperiences == true else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience tracking is disabled in configuration")
            completion(.success(())) // Not an error, just disabled
            return
        }

        // Process the event (location lookup happens in MetricsManager)
        processValidatedExperienceEvent(event)
        completion(.success(()))
    }

    // MARK: - Private Validation

    private func validateProcessingConditions() -> ContentAnalyticsError? {
        // Check configuration state
        guard state.configuration != nil else {
            return .invalidConfiguration
        }

        return nil
    }

    // MARK: - Private Event Processing

    /// Generic method to process a validated event (asset or experience)
    /// - Parameters:
    ///   - event: The validated event
    ///   - entityType: The entity type (for logging)
    ///   - identifier: Closure to extract the entity identifier
    ///   - shouldExclude: Closure to check if the entity should be excluded
    ///   - preProcessing: Optional pre-processing before batching/sending (e.g., storing definition)
    ///   - addToBatch: Closure to add event to batch processor
    ///   - sendImmediately: Closure to send event immediately
    private func processValidatedEvent(
        _ event: Event,
        entityType: String,
        identifier: (Event) -> String?,
        shouldExclude: (Event) -> Bool,
        preProcessing: ((Event) -> Void)? = nil,
        addToBatch: (Event) -> Void,
        sendImmediately: (Event) -> Void
    ) {
        guard let id = identifier(event) else { return }
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processing validated \(entityType) event: \(id)")

        // Check if entity should be excluded
        if shouldExclude(event) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "\(entityType.capitalized) excluded by pattern")
            return
        }

        // Execute any pre-processing (e.g., store experience definition)
        preProcessing?(event)

        // Check if batching is enabled
        if state.batchingEnabled {
            // Add to batch processor for later sending
            addToBatch(event)
            Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Added \(entityType) event to batch")
        } else {
            // Send immediately when batching is disabled
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "⚡ Batching disabled - sending \(entityType) event immediately")
            sendImmediately(event)
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Successfully processed \(entityType) event")
    }

    // MARK: - Event Processing Helpers

    /// Checks if an asset event should be excluded based on URL patterns or location
    private func shouldExcludeAssetEvent(_ event: Event) -> Bool {
        // Check URL pattern exclusion
        if let assetURL = event.assetURL, let url = URL(string: assetURL) {
            if !state.shouldTrackUrl(url) {
                return true
            }
        }

        // Check location exclusion
        if !state.shouldTrackAssetLocation(event.assetLocation) {
            return true
        }

        return false
    }

    /// Checks if an experience event should be excluded based on location patterns
    private func shouldExcludeExperienceEvent(_ event: Event) -> Bool {
        return !state.shouldTrackExperience(location: event.experienceLocation)
    }

    /// Extracts asset context (URL and location) from an event for metrics
    /// assetLocation is optional so we only include it if present
    private func extractAssetContext(_ event: Event) -> [String: Any]? {
        guard let assetURL = event.assetURL else {
            return nil // assetURL is required
        }

        var context: [String: Any] = ["assetURL": assetURL]

        if let assetLocation = event.assetLocation {
            context["assetLocation"] = assetLocation
        }

        return context
    }

    /// Extracts experience context (location) from an event for metrics
    /// experienceLocation is optional so we only include it if present
    private func extractExperienceContext(_ event: Event) -> [String: Any]? {
        guard let experienceID = event.experienceId else { return nil }

        var context: [String: Any] = [
            "experienceID": experienceID
        ]

        if let experienceLocation = event.experienceLocation {
            context["experienceSource"] = experienceLocation
        }

        return context
    }

    /// Store experience definition for asset attribution if this is a registration event
    private func preprocessExperienceDefinition(_ event: Event) {
        guard event.isExperienceDefinition,
              let definitionData = event.extractExperienceDefinitionData() else {
            return
        }

        state.storeExperienceDefinition(
            experienceId: definitionData.experienceId,
            assets: definitionData.assets,
            texts: definitionData.texts,
            ctas: definitionData.ctas
        )

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Stored experience definition: \(definitionData.experienceId) with \(definitionData.assets.count) assets")
    }

    /// Adds an asset event to the batch coordinator
    private func addAssetEventToBatch(_ event: Event) {
        batchCoordinator?.addAssetEvent(event)
    }

    /// Adds an experience event to the batch coordinator
    private func addExperienceEventToBatch(_ event: Event) {
        batchCoordinator?.addExperienceEvent(event)
    }

    /// Processes a validated asset event
    private func processValidatedAssetEvent(_ event: Event) {
        processValidatedEvent(
            event,
            entityType: ContentAnalyticsConstants.EntityType.asset,
            identifier: Self.assetIdentifierExtractor,
            shouldExclude: shouldExcludeAssetEvent,
            addToBatch: addAssetEventToBatch,
            sendImmediately: sendAssetEventImmediately
        )
    }

    /// Processes a validated experience event
    private func processValidatedExperienceEvent(_ event: Event) {
        processValidatedEvent(
            event,
            entityType: ContentAnalyticsConstants.EntityType.experience,
            identifier: Self.experienceIdentifierExtractor,
            shouldExclude: shouldExcludeExperienceEvent,
            preProcessing: preprocessExperienceDefinition,
            addToBatch: addExperienceEventToBatch,
            sendImmediately: sendExperienceEventImmediately
        )
    }

    /// Forces sending of any pending batched events.
    func sendPendingEvents() {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Forcing send of pending events")
        batchCoordinator?.flush()
    }

    /// Clears pending batch without sending (e.g., on identity reset)
    func clearPendingBatch() {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Clearing pending batch without sending")
        batchCoordinator?.clear()
    }

    /// Updates the orchestrator configuration when settings change.
    /// 
    /// When batching is disabled (toggled from enabled to disabled), this method automatically
    /// flushes any pending batched events to ensure they are not lost.
    /// 
    /// - Parameter config: The new content analytics configuration
    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Updating orchestrator configuration")

        // Check if batching was enabled and is now being disabled
        let wasBatchingEnabled = state.batchingEnabled
        let isNowDisabled = !config.batchingEnabled

        if wasBatchingEnabled && isNowDisabled {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "🔄 Batching disabled - flushing pending events before configuration update")
            batchCoordinator?.flush()
        }

        // Update batch coordinator with new configuration
        batchCoordinator?.updateConfiguration(config.toBatchingConfiguration())
    }

    // MARK: - Immediate Send (Non-Batched Mode)

    /// Generic method to send a single event immediately without batching
    /// - Parameters:
    ///   - event: The event to send immediately
    ///   - entityType: The type of entity (e.g., "asset", "experience")
    ///   - keyExtractor: Closure that extracts the entity key from the event
    ///   - processEvents: Closure that processes the events (single or batch)
    private func sendEventImmediately(
        _ event: Event,
        entityType: String,
        keyExtractor: (Event) -> String?,
        processEvents: ([Event]) -> Void
    ) {
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "⚡ Sending \(entityType) event immediately (batching disabled)")

        guard keyExtractor(event) != nil else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Cannot send \(entityType) event - missing required fields")
            return
        }

        // Process as a single event (metrics will be calculated from events)
        processEvents([event])
    }

    /// Sends a single asset event immediately without batching
    private func sendAssetEventImmediately(_ event: Event) {
        sendEventImmediately(event, entityType: ContentAnalyticsConstants.EntityType.asset, keyExtractor: Self.assetKeyExtractor, processEvents: processAssetEvents)
    }

    /// Sends a single experience event immediately without batching
    private func sendExperienceEventImmediately(_ event: Event) {
        sendEventImmediately(event, entityType: ContentAnalyticsConstants.EntityType.experience, keyExtractor: Self.experienceKeyExtractor, processEvents: processExperienceEvents)
    }

    // MARK: - Batch Processing

    func handleAssetBatchFlush(requests events: [Event]) {
        guard !events.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "handleAssetBatchFlush called with empty events array")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "handleAssetBatchFlush | Events: \(events.count)")

        processAssetEvents(events)
    }

    func handleExperienceBatchFlush(requests events: [Event]) {
        guard !events.isEmpty else { return }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "handleExperienceBatchFlush | Events: \(events.count)")

        processExperienceEvents(events)
    }

    /// Process asset events (single or batch) and dispatch to Edge Network
    private func processAssetEvents(_ assetEvents: [Event]) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Processing asset events | EventCount: \(assetEvents.count)")

        // Build typed metrics collection
        let (metricsCollection, interactionType) = buildAssetMetricsCollection(from: assetEvents)

        guard !metricsCollection.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "No valid metrics to send - skipping")
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Built aggregated metrics | AssetCount: \(metricsCollection.count)")

        // Send one Edge event per asset key (enables CJA filtering by assetID and location)
        for assetKey in metricsCollection.assetKeys {
            guard let metrics = metricsCollection.metrics(for: assetKey) else { continue }

            sendAssetInteractionEvent(
                assetKeys: [assetKey],
                aggregatedMetrics: [assetKey: metrics.toEventData()],
                interactionType: interactionType,
                xdmEventBuilder: xdmEventBuilder
            )
        }
    }

    /// Process experience events, send definitions to featurization service, and dispatch interactions to Edge
    private func processExperienceEvents(_ experienceEvents: [Event]) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Processing experience events | EventCount: \(experienceEvents.count)")

        // Group by experienceId to handle definitions and interactions separately
        let eventsByExperienceId = Dictionary(grouping: experienceEvents) { $0.experienceId ?? "" }

        for (experienceId, events) in eventsByExperienceId where !experienceId.isEmpty {
            // Send definition to featurization service if not already sent
            if !state.hasExperienceDefinitionBeenSent(for: experienceId) {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                         "📤 Sending experience definition to featurization | ID: \(experienceId)")
                sendExperienceDefinitionEvent(experienceId: experienceId, events: events)
                state.markExperienceDefinitionAsSent(experienceId: experienceId)
            } else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                         "⏭️ Skipping featurization - definition already sent | ID: \(experienceId)")
            }

            // Only send view/click interactions to Edge (filter out definition events)
            let interactionEvents = events.interactions

            if !interactionEvents.isEmpty {
                // Build typed metrics collection
                let (metricsCollection, interactionType) = buildExperienceMetricsCollection(from: interactionEvents)

                guard !metricsCollection.isEmpty else {
                    Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                               "No metrics found for experience: \(experienceId)")
                    continue
                }

                // Send one Edge event per experience key (enables CJA filtering by experienceID and location)
                for experienceKey in metricsCollection.experienceKeys {
                    guard let metrics = metricsCollection.metrics(for: experienceKey) else { continue }

                    sendExperienceInteractionEvent(
                        experienceId: experienceId,
                        metrics: metrics,
                        interactionType: interactionType,
                        xdmEventBuilder: xdmEventBuilder
                    )
                }
            } else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                         "Skipping Edge event for \(experienceId) - only definition, no interactions")
            }
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Successfully sent experience batch via Edge")
    }

    /// Queue experience definition to featurization service for ML training
    private func sendExperienceDefinitionEvent(experienceId: String, events: [Event]) {
        // Check consent for direct HTTP calls (Edge Network events are validated by Edge extension, but featurization bypasses Edge)
        guard privacyValidator.isDataCollectionAllowed() else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Skipping featurization - consent denied (check privacy validator logs above for details)")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "✅ Privacy check passed - proceeding with featurization")

        guard let config = state.configuration else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Skipping featurization - No configuration available")
            return
        }

        guard let serviceUrl = config.getFeaturizationBaseUrl(),
              !serviceUrl.isEmpty else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Skipping featurization - Cannot determine featurization URL | edge.domain: \(config.edgeDomain ?? "nil") | region: \(config.region ?? "nil")")
            return
        }

        guard let imsOrg = config.experienceCloudOrgId,
              !imsOrg.isEmpty else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Skipping featurization - IMS Org not configured | experienceCloud.org: \(config.experienceCloudOrgId ?? "nil")")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "✅ Configuration valid | URL: \(serviceUrl) | Org: \(imsOrg)")

        // Get definition from state (registerExperience() must be called first)
        guard let definition = state.getExperienceDefinition(for: experienceId) else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "❌ No definition found for experience: \(experienceId) - registerExperience() must be called first")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "✅ Definition found | ID: \(experienceId) | Assets: \(definition.assets.count) | Texts: \(definition.texts.count)")

        let assetURLs = definition.assets
        let textContent = definition.texts
        let buttonContent = definition.ctas

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Using stored definition for featurization: \(experienceId)")

        // Convert to {value, style} format for featurization service
        let imagesData = assetURLs.map { assetURL -> [String: Any] in
            [
                "value": assetURL,
                "style": [:] as [String: Any]
            ]
        }

        let textsData = textContent.map { $0.toDictionary() }
        let ctasData: [[String: Any]]? = buttonContent?.isEmpty == false ? buttonContent?.map { $0.toDictionary() } : nil

        let contentData = ContentData(
            images: imagesData,
            texts: textsData,
            ctas: ctasData
        )

        // datastreamId is required - ensure it's present
        guard let datastreamId = config.datastreamId, !datastreamId.isEmpty else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Cannot send experience to featurization - datastreamId not configured")
            return
        }

        let content = ExperienceContent(
            content: contentData,
            orgId: imsOrg,
            datastreamId: datastreamId,
            experienceId: experienceId
        )

        let hit = FeaturizationHit(
            experienceId: experienceId,
            imsOrg: imsOrg,
            content: content,
            timestamp: Date(),
            attemptCount: 0
        )

        guard let hitData = try? JSONEncoder().encode(hit) else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Failed to encode featurization hit | ExperienceID: \(experienceId)")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "✅ Hit encoded | Size: \(hitData.count) bytes")

        let dataEntity = DataEntity(
            uniqueIdentifier: UUID().uuidString,
            timestamp: Date(),
            data: hitData
        )

        // Check if queue is available
        guard let queue = featurizationHitQueue else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Featurization queue is nil - cannot queue hit | ID: \(experienceId)")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "✅ Queue available | Attempting to queue hit...")

        // Queue hit (persisted to disk and retried automatically)
        if queue.queue(entity: dataEntity) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "✅ Experience queued for featurization | ID: \(experienceId)")
        } else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Failed to queue experience (queue.queue() returned false) | ID: \(experienceId)")
        }
    }

    /// Sends asset interaction event with aggregated metrics to Edge Network
    private func sendAssetInteractionEvent(
        assetKeys: [String],
        aggregatedMetrics: [String: [String: Any]],
        interactionType: InteractionType,
        xdmEventBuilder: XDMEventBuilderProtocol
    ) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Sending interaction event for \(assetKeys.count) assets")

        let xdmData = xdmEventBuilder.createAssetXDMEvent(
            from: assetKeys,
            metrics: aggregatedMetrics,
            triggeringInteractionType: interactionType
        )

        sendToEdge(
            xdm: xdmData,
            eventName: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET,
            eventType: "Asset"
        )

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Successfully sent asset batch via Edge")
    }

    /// Sends experience interaction event with aggregated metrics to Edge Network
    private func sendExperienceInteractionEvent(
        experienceId: String,
        metrics: ExperienceMetrics,
        interactionType: InteractionType,
        xdmEventBuilder: XDMEventBuilderProtocol
    ) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Sending interaction event for experience: \(experienceId)")

        let experienceLocation = !metrics.experienceSource.isEmpty ? metrics.experienceSource : nil

        if experienceLocation == nil {
            Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "No experienceLocation for: \(experienceId) (optional)")
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Using aggregated metrics | Views: \(metrics.viewCount) | Clicks: \(metrics.clickCount)")

        // Get attributed assets directly from metrics
        let assetURLs = metrics.attributedAssets
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Including \(assetURLs.count) attributed assets in experience XDM")

        // Convert metrics to event data for XDM builder
        let aggregatedMetrics = metrics.toEventData()

        let xdmData = xdmEventBuilder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: interactionType,
            metrics: aggregatedMetrics,
            assetURLs: assetURLs,
            experienceLocation: experienceLocation,
            state: state
        )

        sendToEdge(
            xdm: xdmData,
            eventName: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_EXPERIENCE,
            eventType: "Experience"
        )

        let viewCount = (aggregatedMetrics["viewCount"] as? NSNumber)?.intValue ?? 0
        let clickCount = (aggregatedMetrics["clickCount"] as? NSNumber)?.intValue ?? 0
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Successfully sent experience interaction via Edge | Views: \(viewCount) | Clicks: \(clickCount)")
    }

    // MARK: - Edge Network Dispatch

    /// Sends XDM data to Edge Network with optional configuration overrides
    private func sendToEdge(xdm: [String: Any], eventName: String, eventType: String) {
        var eventData: [String: Any] = ["xdm": xdm]

        // Add datastream override if configured
        if let configOverride = buildEdgeConfigOverride() {
            eventData["config"] = configOverride
        }

        let event = Event(
            name: eventName,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: eventData
        )

        eventDispatcher.dispatch(event: event)

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Dispatched \(eventType) event to Edge Network")
    }

    // MARK: - Helper Methods

    /// Builds Edge configuration override for datastream
    private func buildEdgeConfigOverride() -> [String: Any]? {
        guard let config = state.configuration else { return nil }

        guard let datastreamId = config.datastreamId else { return nil }

        let configOverride: [String: Any] = [
            "datastreamIdOverride": datastreamId
        ]

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "Using datastream override: \(datastreamId)")

        return configOverride
    }

    private func processExtras(
        _ extrasArray: [[String: Any]],
        for entityId: String,
        type extrasType: String
    ) -> [String: Any]? {
        guard !extrasArray.isEmpty else { return nil }

        // Single event - no conflicts
        if extrasArray.count == 1 {
            return extrasArray[0]
        }

        // Multiple events - merge and check for conflicts
        var mergedExtras: [String: Any] = [:]
        for extras in extrasArray {
            mergedExtras.merge(extras) { _, new in new }
        }

        if ContentAnalyticsUtilities.hasConflictingExtras(extrasArray) {
            // Conflicts detected - use "all" array only
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "Detected conflicting \(extrasType) for \(entityId) - using 'all' array with \(extrasArray.count) entries")
            return ["all": extrasArray]
        } else {
            // No conflicts - use merged
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "Merged \(extrasType) for \(entityId) | Events: \(extrasArray.count) | Fields: \(mergedExtras.count)")
            return mergedExtras
        }
    }

    // MARK: - Helper Methods for Metrics Calculation

    /// Build aggregated metrics with context and extras in one pass from events
    /// - Parameters:
    ///   - events: Array of events to process
    ///   - keyExtractor: Closure that extracts the grouping key from each event
    ///   - contextExtractor: Closure that extracts context fields from a representative event
    ///   - extrasKey: Optional key for extras field (e.g., "assetExtras", "experienceExtras")
    ///   - extrasExtractor: Optional closure to extract extras from events
    /// - Returns: Dictionary mapping keys to aggregated metrics with context, extras, and interaction type
    /// Builds typed asset metrics from events
    private func buildAssetMetricsCollection(from events: [Event]) -> (collection: AssetMetricsCollection, interactionType: InteractionType) {
        let groupedEvents = Dictionary(grouping: events) { $0.assetKey ?? "" }
        var metricsMap: [String: AssetMetrics] = [:]

        for (key, groupedEvents) in groupedEvents where !key.isEmpty {
            guard let firstEvent = groupedEvents.first,
                  let context = extractAssetContext(firstEvent),
                  let assetURL = context["assetURL"] as? String else {
                continue
            }

            // assetLocation is optional
            let assetLocation = context["assetLocation"] as? String ?? ""

            let viewCount = Double(groupedEvents.viewCount)
            let clickCount = Double(groupedEvents.clickCount)

            // Process extras
            let allExtras = groupedEvents.compactMap { $0.assetExtras }
            let processedExtras = processExtras(allExtras, for: key, type: AssetTrackingEventPayload.OptionalFields.assetExtras)

            let metrics = AssetMetrics(
                assetURL: assetURL,
                assetLocation: assetLocation,
                viewCount: viewCount,
                clickCount: clickCount,
                assetExtras: processedExtras
            )

            metricsMap[key] = metrics
        }

        let interactionType = events.triggeringInteractionType
        return (AssetMetricsCollection(metrics: metricsMap), interactionType)
    }

    /// Builds typed experience metrics from events
    private func buildExperienceMetricsCollection(from events: [Event]) -> (collection: ExperienceMetricsCollection, interactionType: InteractionType) {
        let groupedEvents = Dictionary(grouping: events) { $0.experienceKey ?? "" }
        var metricsMap: [String: ExperienceMetrics] = [:]

        for (key, groupedEvents) in groupedEvents where !key.isEmpty {
            guard let firstEvent = groupedEvents.first,
                  let context = extractExperienceContext(firstEvent),
                  let experienceID = context["experienceID"] as? String else {
                continue
            }

            // experienceSource (location) is optional
            let experienceSource = context["experienceSource"] as? String ?? ""

            let viewCount = Double(groupedEvents.viewCount)
            let clickCount = Double(groupedEvents.clickCount)

            // Process extras
            let allExtras = groupedEvents.compactMap { $0.experienceExtras }
            let processedExtras = processExtras(allExtras, for: key, type: ExperienceTrackingEventPayload.OptionalFields.experienceExtras)

            // Get attributed assets from stored definition
            let assetURLs: [String]
            if let definition = state.getExperienceDefinition(for: experienceID) {
                assetURLs = definition.assets
            } else {
                assetURLs = []
                Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                           "No definition found for experience: \(experienceID) - may not be registered")
            }

            let metrics = ExperienceMetrics(
                experienceID: experienceID,
                experienceSource: experienceSource,
                viewCount: viewCount,
                clickCount: clickCount,
                experienceExtras: processedExtras,
                attributedAssets: assetURLs
            )

            metricsMap[key] = metrics
        }

        let interactionType = events.triggeringInteractionType
        return (ExperienceMetricsCollection(metrics: metricsMap), interactionType)
    }

}
