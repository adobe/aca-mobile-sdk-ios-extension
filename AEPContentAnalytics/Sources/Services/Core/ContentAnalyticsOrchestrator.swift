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

/// Orchestrates Content Analytics event processing by coordinating between specialized components.
/// This class acts as a thin coordinator, delegating validation, filtering, metrics building,
/// and event processing to dedicated components.
class ContentAnalyticsOrchestrator: ContentAnalyticsOrchestrating {

    // MARK: - Dependencies
    
    private let state: ContentAnalyticsStateManager
    private let eventValidator: EventValidating
    private let eventExclusionFilter: EventExclusionFiltering
    private let assetEventProcessor: AssetEventProcessing
    private let experienceEventProcessor: ExperienceEventProcessing
    private let featurizationCoordinator: FeaturizationCoordinator
    private let batchCoordinator: BatchCoordinating?

    // MARK: - Initialization

    init(
        state: ContentAnalyticsStateManager,
        eventValidator: EventValidating,
        eventExclusionFilter: EventExclusionFiltering,
        assetEventProcessor: AssetEventProcessing,
        experienceEventProcessor: ExperienceEventProcessing,
        featurizationCoordinator: FeaturizationCoordinator,
        batchCoordinator: BatchCoordinating?
    ) {
        self.state = state
        self.eventValidator = eventValidator
        self.eventExclusionFilter = eventExclusionFilter
        self.assetEventProcessor = assetEventProcessor
        self.experienceEventProcessor = experienceEventProcessor
        self.featurizationCoordinator = featurizationCoordinator
        self.batchCoordinator = batchCoordinator

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Orchestrator initialized")
    }

    // MARK: - Featurization Queue Management

    func hasFeaturizationQueue() -> Bool {
        return featurizationCoordinator.hasQueue
    }

    func initializeFeaturizationQueueIfNeeded(queue: PersistentHitQueue?) {
        featurizationCoordinator.initializeQueue(queue)
    }

    // MARK: - Event Processing

    func processAssetEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void) {
        // Validate using EventValidator
        let validationResult = eventValidator.validateAssetEvent(event)
        if case .failure(let error) = validationResult {
            completion(.failure(error))
            return
        }
        
        // Check processing conditions
        if let error = eventValidator.validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Process the validated event
        processValidatedAssetEvent(event)
        completion(.success(()))
    }

    func processExperienceEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void) {
        // Validate using EventValidator
        let validationResult = eventValidator.validateExperienceEvent(event)
        if case .failure(let error) = validationResult {
            completion(.failure(error))
            return
        }
        
        // Check processing conditions
        if let error = eventValidator.validateProcessingConditions() {
            completion(.failure(error))
            return
        }

        // Check if experience tracking is enabled
        guard eventValidator.isExperienceTrackingEnabled() else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience tracking is disabled in configuration")
            completion(.success(())) // Not an error, just disabled
            return
        }

        // Process the validated event
        processValidatedExperienceEvent(event)
        completion(.success(()))
    }

    // MARK: - Batch Management

    func sendPendingEvents() {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Forcing send of pending events")
        batchCoordinator?.flush()
    }

    func clearPendingBatch() {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Clearing pending batch without sending")
        batchCoordinator?.clearPendingBatch()
    }

    // MARK: - Configuration

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

    // MARK: - Batch Flush Handlers

    func handleAssetBatchFlush(requests events: [Event]) {
        guard !events.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleAssetBatchFlush called with empty events array")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleAssetBatchFlush | Events: \(events.count)")
        assetEventProcessor.processAssetEvents(events)
    }

    func handleExperienceBatchFlush(requests events: [Event]) {
        guard !events.isEmpty else { return }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "handleExperienceBatchFlush | Events: \(events.count)")
        experienceEventProcessor.processExperienceEvents(events)
    }

    // MARK: - Private Helpers

    private func processValidatedAssetEvent(_ event: Event) {
        guard event.assetURL != nil else { return }

        // Check exclusion using EventExclusionFilter
        if eventExclusionFilter.shouldExcludeAsset(event) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Asset excluded by pattern")
            return
        }

        // When excludeAssetsFromUntrackedExperience is true, exclude assets that belong to excluded experiences.
        // Attribution: experiences are registered with asset URLs; we store all definitions (including excluded) so we can look up by asset.
        if let config = state.getCurrentConfiguration(), config.excludeAssetsFromUntrackedExperience,
           let assetURL = event.assetURL {
            let definitionsContainingAsset = state.getDefinitionsContainingAsset(assetURL)
            for definition in definitionsContainingAsset {
                if let location = definition.experienceLocation, config.shouldExcludeExperience(location: location) {
                    Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Asset excluded (belongs to untracked experience): \(location)")
                    return
                }
            }
            // Also exclude if asset event carries an excluded experience location (e.g. no definition was registered)
            if let eventLocation = event.experienceLocation, config.shouldExcludeExperience(location: eventLocation) {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Asset excluded (experience untracked): \(eventLocation)")
                return
            }
        }

        // Route to batch or immediate processing
        if state.batchingEnabled {
            batchCoordinator?.addAssetEvent(event)
        } else {
            assetEventProcessor.sendAssetEventImmediately(event)
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processed asset event")
    }

    private func processValidatedExperienceEvent(_ event: Event) {
        guard event.experienceId != nil else { return }

        // Store definition payload (assets/texts/CTAs) so we can attribute assets to experiences later.
        // Must happen before exclusion so definitions for excluded experiences are still cached.
        preprocessExperienceDefinition(event)

        // Update the last-seen location for this experience from view events.
        // Location is NOT part of the definition registration — the same experience can be viewed
        // at different locations without re-registering. This must also happen before exclusion so
        // that the location is captured even when the view event itself is filtered out.
        captureExperienceLocation(event)

        // Check exclusion using EventExclusionFilter (experience event not sent if excluded)
        if eventExclusionFilter.shouldExcludeExperience(event) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Experience excluded by pattern")
            return
        }

        // Route to batch or immediate processing
        if state.batchingEnabled {
            // Only add interaction events to batch, skip definition events
            if !event.isExperienceDefinition {
                batchCoordinator?.addExperienceEvent(event)
            }
        } else {
            experienceEventProcessor.sendExperienceEventImmediately(event)
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Processed experience event")
    }

    /// Stores the experience definition payload (assets/texts/CTAs) for asset attribution.
    /// Only processes definition-type events; location is handled separately via captureExperienceLocation.
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

    /// Updates the last-seen location for an experience from any event that carries one.
    /// Called for view/click events (and definition events if they happen to include a location)
    /// before the exclusion filter, so the location is captured even for excluded experiences.
    private func captureExperienceLocation(_ event: Event) {
        guard let experienceId = event.experienceId,
              let location = event.experienceLocation else { return }
        state.updateExperienceLocation(experienceId: experienceId, location: location)
    }
}
