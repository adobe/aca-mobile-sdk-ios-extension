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

class ContentAnalyticsOrchestrator {

    private static let assetKeyExtractor: (Event) -> String? = { $0.assetKey }
    private static let experienceKeyExtractor: (Event) -> String? = { $0.experienceKey }
    private static let assetIdentifierExtractor: (Event) -> String? = { $0.assetURL }
    private static let experienceIdentifierExtractor: (Event) -> String? = { $0.experienceId }
    private static let assetExtrasExtractor: (Event) -> [String: Any]? = { $0.assetExtras }
    private static let experienceExtrasExtractor: (Event) -> [String: Any]? = { $0.experienceExtras }

    private let state: ContentAnalyticsStateManager
    private let eventDispatcher: ContentAnalyticsEventDispatcher
    private let privacyValidator: PrivacyValidator
    private let xdmEventBuilder: XDMEventBuilderProtocol
    private let featurizationCoordinator: FeaturizationCoordinator
    private let batchCoordinator: BatchCoordinating?

    init(
        state: ContentAnalyticsStateManager,
        eventDispatcher: ContentAnalyticsEventDispatcher,
        privacyValidator: PrivacyValidator,
        xdmEventBuilder: XDMEventBuilderProtocol,
        featurizationCoordinator: FeaturizationCoordinator,
        batchCoordinator: BatchCoordinating?
    ) {
        self.state = state
        self.eventDispatcher = eventDispatcher
        self.privacyValidator = privacyValidator
        self.xdmEventBuilder = xdmEventBuilder
        self.featurizationCoordinator = featurizationCoordinator
        self.batchCoordinator = batchCoordinator

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Orchestrator initialized with featurization coordinator")
    }

    func hasFeaturizationQueue() -> Bool {
        return featurizationCoordinator.hasQueue
    }

    func initializeFeaturizationQueueIfNeeded(queue: PersistentHitQueue?) {
        featurizationCoordinator.initializeQueue(queue)
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
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Asset event has invalid action: \(action)")
            completion(.failure(.validationError("Invalid action type: \(action)")))
            return
        }

        // Validate processing conditions
        if let error = validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Process the event (synchronous - batching or immediate dispatch)
        processValidatedAssetEvent(event)
        
        // Processing succeeded (event validated and queued/dispatched)
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
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience event has invalid action: \(action)")
            completion(.failure(.validationError("Invalid action type: \(action)")))
            return
        }

        // Validate processing conditions
        if let error = validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Experience-specific validation
        guard state.getCurrentConfiguration()?.trackExperiences == true else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience tracking is disabled in configuration")
            completion(.success(())) // Not an error, just disabled
            return
        }

        // Process the event (synchronous - batching or immediate dispatch)
        processValidatedExperienceEvent(event)
        
        // Processing succeeded (event validated and queued/dispatched)
        completion(.success(()))
    }

    private func validateProcessingConditions() -> ContentAnalyticsError? {
        // Check configuration state
        guard state.getCurrentConfiguration() != nil else {
            return .invalidConfiguration
        }

        return nil
    }

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

        // Check if entity should be excluded
        if shouldExclude(event) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "\(entityType.capitalized) excluded by pattern")
            return
        }

        preProcessing?(event)

        // Check if batching is enabled
        if state.batchingEnabled {
            // Add to batch processor for later sending
            addToBatch(event)
        } else {
            // Send immediately when batching is disabled
            sendImmediately(event)
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processed \(entityType) event: \(id)")
    }

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

    private func shouldExcludeExperienceEvent(_ event: Event) -> Bool {
        return !state.shouldTrackExperience(location: event.experienceLocation)
    }

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

        state.registerExperienceDefinition(
            experienceId: definitionData.experienceId,
            assets: definitionData.assets,
            texts: definitionData.texts,
            ctas: definitionData.ctas
        )

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Stored experience definition: \(definitionData.experienceId) with \(definitionData.assets.count) assets")
    }

    /// Adds an asset event to the batch coordinator
    private func addAssetEventToBatch(_ event: Event) {
        batchCoordinator?.addAssetEvent(event)
    }

    private func addExperienceEventToBatch(_ event: Event) {
        guard !event.isExperienceDefinition else {
            return
        }
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

    func clearPendingBatch() {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Clearing pending batch without sending")
        batchCoordinator?.clearPendingBatch()
    }

    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Updating orchestrator configuration")

        // Check if batching was enabled and is now being disabled
        let wasBatchingEnabled = state.batchingEnabled
        let isNowDisabled = !config.batchingEnabled

        if wasBatchingEnabled && isNowDisabled {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Batching disabled - flushing pending events")
            batchCoordinator?.flush()
        }

        // Update batch coordinator with new configuration
        batchCoordinator?.updateConfiguration(config.toBatchingConfiguration())
    }

    private func sendEventImmediately(
        _ event: Event,
        entityType: String,
        keyExtractor: (Event) -> String?,
        processEvents: ([Event]) -> Void
    ) {
        guard let key = keyExtractor(event) else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Cannot send \(entityType) event - missing required fields")
            return
        }

        // Process as a single event (metrics will be calculated from events)
        processEvents([event])
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Sent \(entityType) event immediately: \(key)")
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
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleAssetBatchFlush called with empty events array")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleAssetBatchFlush | Events: \(events.count)")

        processAssetEvents(events)
    }

    func handleExperienceBatchFlush(requests events: [Event]) {
        guard !events.isEmpty else { return }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleExperienceBatchFlush | Events: \(events.count)")

        processExperienceEvents(events)
    }

    private func processAssetEvents(_ assetEvents: [Event]) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processing asset events | EventCount: \(assetEvents.count)")

        // Build typed metrics collection
        let (metricsCollection, interactionType) = buildAssetMetricsCollection(from: assetEvents)

        guard !metricsCollection.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "No valid metrics to send - skipping")
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Built aggregated metrics | AssetCount: \(metricsCollection.count)")

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
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processing experience events | EventCount: \(experienceEvents.count)")

        // Group by experienceId to handle definitions and interactions separately
        let eventsByExperienceId = Dictionary(grouping: experienceEvents) { $0.experienceId ?? "" }

        for (experienceId, events) in eventsByExperienceId where !experienceId.isEmpty {
            // Send definition to featurization service if not already sent
            if !state.hasExperienceDefinitionBeenSent(for: experienceId) {
                sendExperienceDefinitionEvent(experienceId: experienceId, events: events)
                state.markExperienceDefinitionAsSent(experienceId: experienceId)
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Sent experience definition | ID: \(experienceId)")
            } else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Skipping featurization - already sent | ID: \(experienceId)")
            }

            // Only send view/click interactions to Edge (filter out definition events)
            let interactionEvents = events.interactions

            if !interactionEvents.isEmpty {
                // Build typed metrics collection
                let (metricsCollection, interactionType) = buildExperienceMetricsCollection(from: interactionEvents)

                guard !metricsCollection.isEmpty else {
                    Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "No metrics found for experience: \(experienceId)")
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
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Skipping Edge event for \(experienceId) - only definition, no interactions")
            }
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience batch sent")
    }

    private func sendExperienceDefinitionEvent(experienceId: String, events: [Event]) {
        featurizationCoordinator.queueExperience(experienceId: experienceId)
    }

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

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Asset batch sent")
    }

    /// Sends experience interaction event with aggregated metrics to Edge Network
    private func sendExperienceInteractionEvent(
        experienceId: String,
        metrics: ExperienceMetrics,
        interactionType: InteractionType,
        xdmEventBuilder: XDMEventBuilderProtocol
    ) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Sending interaction event for experience: \(experienceId)")

        let experienceLocation = !metrics.experienceSource.isEmpty ? metrics.experienceSource : nil

        if experienceLocation == nil {
            Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "No experienceLocation for: \(experienceId) (optional)")
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Using aggregated metrics | Views: \(metrics.viewCount) | Clicks: \(metrics.clickCount)")

        // Get attributed assets directly from metrics
        let assetURLs = metrics.attributedAssets
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Including \(assetURLs.count) attributed assets in experience XDM")

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
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience interaction sent (views=\(viewCount), clicks=\(clickCount))")
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

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Dispatched \(eventType) event to Edge Network")
    }

    // MARK: - Helper Methods

    /// Builds Edge configuration override for datastream
    private func buildEdgeConfigOverride() -> [String: Any]? {
        guard let config = state.getCurrentConfiguration() else { return nil }

        guard let datastreamId = config.datastreamId else { return nil }

        let configOverride: [String: Any] = [
            "datastreamIdOverride": datastreamId
        ]

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Using datastream override: \(datastreamId)")

        return configOverride
    }

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
            let processedExtras = ContentAnalyticsUtilities.processExtras(
                allExtras,
                for: key,
                type: AssetTrackingEventPayload.OptionalFields.assetExtras
            )

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
            let processedExtras = ContentAnalyticsUtilities.processExtras(
                allExtras,
                for: key,
                type: ExperienceTrackingEventPayload.OptionalFields.experienceExtras
            )

            // Get attributed assets from stored definition
            let assetURLs: [String]
            if let definition = state.getExperienceDefinition(for: experienceID) {
                assetURLs = definition.assets
            } else {
                assetURLs = []
                Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "No definition found for experience: \(experienceID) - may not be registered")
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
