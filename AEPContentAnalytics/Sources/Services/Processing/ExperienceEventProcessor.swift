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

/// Processes experience events and dispatches them to Edge Network
class ExperienceEventProcessor: ExperienceEventProcessing {
    
    private let state: ContentAnalyticsStateManager
    private let eventDispatcher: ContentAnalyticsEventDispatcher
    private let xdmEventBuilder: XDMEventBuilderProtocol
    private let metricsBuilder: MetricsBuilding
    private let featurizationCoordinator: FeaturizationCoordinator
    
    init(
        state: ContentAnalyticsStateManager,
        eventDispatcher: ContentAnalyticsEventDispatcher,
        xdmEventBuilder: XDMEventBuilderProtocol,
        metricsBuilder: MetricsBuilding,
        featurizationCoordinator: FeaturizationCoordinator
    ) {
        self.state = state
        self.eventDispatcher = eventDispatcher
        self.xdmEventBuilder = xdmEventBuilder
        self.metricsBuilder = metricsBuilder
        self.featurizationCoordinator = featurizationCoordinator
    }
    
    func processExperienceEvents(_ events: [Event]) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Processing experience events | EventCount: \(events.count)")
        
        // Group by experienceId to handle definitions and interactions separately
        let eventsByExperienceId = Dictionary(grouping: events) { $0.experienceId ?? "" }
        
        for (experienceId, eventsForExperience) in eventsByExperienceId where !experienceId.isEmpty {
            // Send definition to featurization service if not already sent
            if !state.hasExperienceDefinitionBeenSent(for: experienceId) {
                sendExperienceDefinitionEvent(experienceId: experienceId)
                state.markExperienceDefinitionAsSent(experienceId: experienceId)
                Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Sent experience definition | ID: \(experienceId)")
            } else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Skipping featurization - already sent | ID: \(experienceId)")
            }
            
            // Only send view/click interactions to Edge (filter out definition events)
            let interactionEvents = eventsForExperience.interactions
            
            if !interactionEvents.isEmpty {
                // Build typed metrics collection
                let (metricsCollection, interactionType) = metricsBuilder.buildExperienceMetrics(from: interactionEvents)
                
                guard !metricsCollection.isEmpty else {
                    Log.warning(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "No metrics found for experience: \(experienceId)")
                    continue
                }
                
                // Send one Edge event per experience key (enables CJA filtering by experienceID and location)
                for experienceKey in metricsCollection.experienceKeys {
                    guard let metrics = metricsCollection.metrics(for: experienceKey) else { continue }
                    
                    sendExperienceInteractionEvent(
                        experienceId: experienceId,
                        metrics: metrics,
                        interactionType: interactionType
                    )
                }
            } else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Skipping Edge event for \(experienceId) - only definition, no interactions")
            }
        }
        
        Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Experience batch sent")
    }
    
    func sendExperienceEventImmediately(_ event: Event) {
        guard event.experienceKey != nil else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Cannot send experience event - missing required fields")
            return
        }
        
        // Process as a single event
        processExperienceEvents([event])
        Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Sent experience event immediately")
    }
    
    // MARK: - Private Helpers
    
    private func sendExperienceDefinitionEvent(experienceId: String) {
        featurizationCoordinator.queueExperience(experienceId: experienceId)
    }
    
    private func sendExperienceInteractionEvent(
        experienceId: String,
        metrics: ExperienceMetrics,
        interactionType: InteractionType
    ) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Sending interaction event for experience: \(experienceId)")
        
        let experienceLocation = !metrics.experienceSource.isEmpty ? metrics.experienceSource : nil
        
        if experienceLocation == nil {
            Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "No experienceLocation for: \(experienceId) (optional)")
        }
        
        Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Using aggregated metrics | Views: \(metrics.viewCount) | Clicks: \(metrics.clickCount)")
        
        // Get attributed assets directly from metrics
        let assetURLs = metrics.attributedAssets
        Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Including \(assetURLs.count) attributed assets in experience XDM")
        
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
        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Experience interaction sent (views=\(viewCount), clicks=\(clickCount))")
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
        
        Log.trace(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Dispatched \(eventType) event to Edge Network")
    }
    
    private func buildEdgeConfigOverride() -> [String: Any]? {
        guard let config = state.getCurrentConfiguration() else { return nil }
        guard let datastreamId = config.datastreamId else { return nil }
        
        let configOverride: [String: Any] = [
            "datastreamIdOverride": datastreamId
        ]
        
        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXPERIENCE_PROCESSOR, "Using datastream override: \(datastreamId)")
        
        return configOverride
    }
}
