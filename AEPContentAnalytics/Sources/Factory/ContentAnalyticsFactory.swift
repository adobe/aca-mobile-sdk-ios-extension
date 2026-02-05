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

/// Factory for creating ContentAnalytics services and dependencies
class ContentAnalyticsFactory {

    private let extensionRuntime: ExtensionRuntime
    private let state: ContentAnalyticsStateManager
    private let privacyValidator: PrivacyValidator

    // MARK: - Initialization

    init(extensionRuntime: ExtensionRuntime, state: ContentAnalyticsStateManager, privacyValidator: PrivacyValidator) {
        self.extensionRuntime = extensionRuntime
        self.state = state
        self.privacyValidator = privacyValidator
    }

    // MARK: - Core Service Creation

    func createContentAnalyticsOrchestrator() -> ContentAnalyticsOrchestrator {
        // Create helper components
        let eventDispatcher = createEventDispatcher()
        let xdmEventBuilder = createXDMEventBuilder()
        let featurizationCoordinator = createFeaturizationCoordinator()
        let batchCoordinator = createBatchCoordinator()
        
        // Create processing components
        let eventValidator = createEventValidator()
        let eventExclusionFilter = createEventExclusionFilter()
        let metricsBuilder = createMetricsBuilder()
        
        let assetEventProcessor = AssetEventProcessor(
            state: state,
            eventDispatcher: eventDispatcher,
            xdmEventBuilder: xdmEventBuilder,
            metricsBuilder: metricsBuilder
        )
        
        let experienceEventProcessor = ExperienceEventProcessor(
            state: state,
            eventDispatcher: eventDispatcher,
            xdmEventBuilder: xdmEventBuilder,
            metricsBuilder: metricsBuilder,
            featurizationCoordinator: featurizationCoordinator
        )

        // Create orchestrator with all dependencies
        let orchestrator = ContentAnalyticsOrchestrator(
            state: state,
            eventValidator: eventValidator,
            eventExclusionFilter: eventExclusionFilter,
            assetEventProcessor: assetEventProcessor,
            experienceEventProcessor: experienceEventProcessor,
            featurizationCoordinator: featurizationCoordinator,
            batchCoordinator: batchCoordinator
        )

        // Wire up orchestrator callbacks to batch coordinator
        batchCoordinator?.setCallbacks(
            assetCallback: { [weak orchestrator] events in
                orchestrator?.handleAssetBatchFlush(requests: events)
            },
            experienceCallback: { [weak orchestrator] events in
                orchestrator?.handleExperienceBatchFlush(requests: events)
            }
        )

        return orchestrator
    }
    
    private func createFeaturizationCoordinator() -> FeaturizationCoordinator {
        return FeaturizationCoordinator(state: state, privacyValidator: privacyValidator)
    }

    // MARK: - Processing Component Creation
    
    /// Creates an EventValidator for validating incoming events.
    func createEventValidator() -> EventValidating {
        return EventValidator(state: state)
    }
    
    /// Creates an EventExclusionFilter for filtering events based on configuration.
    func createEventExclusionFilter() -> EventExclusionFiltering {
        return EventExclusionFilter(state: state)
    }
    
    /// Creates a MetricsBuilder for aggregating event metrics.
    func createMetricsBuilder() -> MetricsBuilding {
        return MetricsBuilder(state: state)
    }
    
    /// Creates an AssetEventProcessor for processing asset events.
    func createAssetEventProcessor(
        eventDispatcher: ContentAnalyticsEventDispatcher,
        xdmEventBuilder: XDMEventBuilderProtocol,
        metricsBuilder: MetricsBuilding
    ) -> AssetEventProcessing {
        return AssetEventProcessor(
            state: state,
            eventDispatcher: eventDispatcher,
            xdmEventBuilder: xdmEventBuilder,
            metricsBuilder: metricsBuilder
        )
    }
    
    /// Creates an ExperienceEventProcessor for processing experience events.
    func createExperienceEventProcessor(
        eventDispatcher: ContentAnalyticsEventDispatcher,
        xdmEventBuilder: XDMEventBuilderProtocol,
        metricsBuilder: MetricsBuilding,
        featurizationCoordinator: FeaturizationCoordinator
    ) -> ExperienceEventProcessing {
        return ExperienceEventProcessor(
            state: state,
            eventDispatcher: eventDispatcher,
            xdmEventBuilder: xdmEventBuilder,
            metricsBuilder: metricsBuilder,
            featurizationCoordinator: featurizationCoordinator
        )
    }

    // MARK: - Helper Component Creation

    private func createEventDispatcher() -> ContentAnalyticsEventDispatcher {
        return EdgeEventDispatcher(runtime: extensionRuntime)
    }

    private func createXDMEventBuilder() -> XDMEventBuilderProtocol {
        return XDMEventBuilder()
    }

    func createFeaturizationHitQueue() -> PersistentHitQueue? {
        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: ContentAnalyticsConstants.FEATURIZATION_QUEUE_NAME) else {
            Log.error(label: ContentAnalyticsConstants.LOG_TAG, "Failed to create data queue for featurization")
            return nil
        }

        guard let config = state.getCurrentConfiguration() else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "No configuration available for featurization service")
            return nil
        }

        guard let serviceUrl = config.getFeaturizationBaseUrl() else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Cannot determine featurization URL - Edge domain not configured")
            return nil
        }

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Featurization URL: \(serviceUrl)")

        let featurizationService = ExperienceFeaturizationService(
            baseUrl: serviceUrl,
            networkService: ServiceProvider.shared.networkService
        )

        let hitProcessor = FeaturizationHitProcessor(featurizationService: featurizationService)
        let hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
        hitQueue.beginProcessing() // Queue starts suspended by default

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Featurization queue ready")

        return hitQueue
    }

    private func createBatchCoordinator() -> BatchCoordinator? {
        guard let assetDataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: ContentAnalyticsConstants.ASSET_BATCH_QUEUE_NAME) else {
            Log.error(label: ContentAnalyticsConstants.LOG_TAG, "Failed to create asset batch data queue")
            return nil
        }

        guard let experienceDataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: ContentAnalyticsConstants.EXPERIENCE_BATCH_QUEUE_NAME) else {
            Log.error(label: ContentAnalyticsConstants.LOG_TAG, "Failed to create experience batch data queue")
            return nil
        }

        let batchCoordinator = BatchCoordinator(
            assetDataQueue: assetDataQueue,
            experienceDataQueue: experienceDataQueue,
            state: state
        )

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "BatchCoordinator ready")

        return batchCoordinator
    }
}
