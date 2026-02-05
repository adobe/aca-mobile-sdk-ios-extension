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

/// Processes asset events and dispatches them to Edge Network
class AssetEventProcessor: AssetEventProcessing {
    
    private let state: ContentAnalyticsStateManager
    private let eventDispatcher: ContentAnalyticsEventDispatcher
    private let xdmEventBuilder: XDMEventBuilderProtocol
    private let metricsBuilder: MetricsBuilding
    
    init(
        state: ContentAnalyticsStateManager,
        eventDispatcher: ContentAnalyticsEventDispatcher,
        xdmEventBuilder: XDMEventBuilderProtocol,
        metricsBuilder: MetricsBuilding
    ) {
        self.state = state
        self.eventDispatcher = eventDispatcher
        self.xdmEventBuilder = xdmEventBuilder
        self.metricsBuilder = metricsBuilder
    }
    
    func processAssetEvents(_ events: [Event]) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Processing asset events | EventCount: \(events.count)")
        
        // Build typed metrics collection
        let (metricsCollection, interactionType) = metricsBuilder.buildAssetMetrics(from: events)
        
        guard !metricsCollection.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "No valid metrics to send - skipping")
            return
        }
        
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Built aggregated metrics | AssetCount: \(metricsCollection.count)")
        
        // Send one Edge event per asset key (enables CJA filtering by assetID and location)
        for assetKey in metricsCollection.assetKeys {
            guard let metrics = metricsCollection.metrics(for: assetKey) else { continue }
            
            sendAssetInteractionEvent(
                assetKeys: [assetKey],
                aggregatedMetrics: [assetKey: metrics.toEventData()],
                interactionType: interactionType
            )
        }
    }
    
    func sendAssetEventImmediately(_ event: Event) {
        guard event.assetKey != nil else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Cannot send asset event - missing required fields")
            return
        }
        
        // Process as a single event
        processAssetEvents([event])
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Sent asset event immediately")
    }
    
    // MARK: - Private Helpers
    
    private func sendAssetInteractionEvent(
        assetKeys: [String],
        aggregatedMetrics: [String: [String: Any]],
        interactionType: InteractionType
    ) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Sending interaction event for \(assetKeys.count) assets")
        
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
        
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Asset batch sent")
    }
    
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
        
        Log.trace(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Dispatched \(eventType) event to Edge Network")
    }
    
    private func buildEdgeConfigOverride() -> [String: Any]? {
        guard let config = state.getCurrentConfiguration() else { return nil }
        guard let datastreamId = config.datastreamId else { return nil }
        
        let configOverride: [String: Any] = [
            "datastreamIdOverride": datastreamId
        ]
        
        Log.debug(label: ContentAnalyticsConstants.LogLabels.ASSET_PROCESSOR, "Using datastream override: \(datastreamId)")
        
        return configOverride
    }
}
