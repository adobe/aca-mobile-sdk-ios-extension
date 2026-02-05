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

/// Builds aggregated metrics collections from events
class MetricsBuilder: MetricsBuilding {
    
    private let state: ContentAnalyticsStateManager
    
    init(state: ContentAnalyticsStateManager) {
        self.state = state
    }
    
    func buildAssetMetrics(from events: [Event]) -> (collection: AssetMetricsCollection, interactionType: InteractionType) {
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
    
    func buildExperienceMetrics(from events: [Event]) -> (collection: ExperienceMetricsCollection, interactionType: InteractionType) {
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
                Log.warning(label: ContentAnalyticsConstants.LogLabels.METRICS_BUILDER, "No definition found for experience: \(experienceID) - may not be registered")
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
    
    // MARK: - Private Helpers
    
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
}
