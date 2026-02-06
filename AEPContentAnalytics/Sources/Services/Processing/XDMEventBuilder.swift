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

protocol AssetXDMBuilder {
    func createAssetXDMEvent(from assetKeys: [String], metrics: [String: [String: Any]], triggeringInteractionType: InteractionType) -> [String: Any]
}

protocol ExperienceXDMBuilder {
    func createExperienceXDMEvent(experienceId: String, interactionType: InteractionType, metrics: [String: Any], assetURLs: [String], experienceLocation: String?, state: ContentAnalyticsStateManager) -> [String: Any]
}

typealias XDMEventBuilderProtocol = AssetXDMBuilder & ExperienceXDMBuilder

/// Creates XDM-compliant payloads for asset and experience tracking events
class XDMEventBuilder: XDMEventBuilderProtocol {

    // MARK: - Private Helpers
    
    /// Converts all values in a dictionary to strings for XDM schema compliance.
    /// The global XDM schema requires meta:xdmType on all fields - using strings ensures compliance.
    private func stringifyExtras(_ extras: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in extras {
            if let stringValue = value as? String {
                result[key] = stringValue
            } else if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                      let jsonString = String(data: data, encoding: .utf8) {
                // Complex types (arrays, dictionaries) become JSON strings
                result[key] = jsonString
            } else {
                // Primitives (Int, Double, Bool) use string interpolation
                result[key] = "\(value)"
            }
        }
        return result
    }

    // MARK: - Asset XDM Event Creation

    func createAssetXDMEvent(from assetKeys: [String], metrics: [String: [String: Any]], triggeringInteractionType: InteractionType) -> [String: Any] {
        let assetData = createAssetDataForXDM(from: assetKeys, metrics: metrics, triggeringInteractionType: triggeringInteractionType)

        let experienceContent: [String: Any] = ["assets": assetData]
        let xdmEvent = createBaseXDMEvent(experienceContent: experienceContent)

        // TRACE: Full XDM payload
        Log.trace(label: ContentAnalyticsConstants.LogLabels.XDM_BUILDER, "Asset XDM Payload | AssetCount: \(assetData.count)")

        return xdmEvent
    }

    // MARK: - Private Helper Methods

    /// Creates base XDM structure with experienceContent
    private func createBaseXDMEvent(experienceContent: [String: Any]) -> [String: Any] {
        // Add channel and idSource inside experienceContent per schema
        var fullExperienceContent = experienceContent
        fullExperienceContent["channel"] = "mobile"
        fullExperienceContent["idSource"] = "ContentAnalytics"
        
        return [
            "eventType": ContentAnalyticsConstants.EventType.xdmContentEngagement,
            "experienceContent": fullExperienceContent
        ]
    }

    // MARK: - Private Asset Methods

    private func createAssetDataForXDM(from assetKeys: [String], metrics: [String: [String: Any]], triggeringInteractionType: InteractionType) -> [[String: Any]] {
        var result: [[String: Any]] = []

        for assetKey in assetKeys {
            // Get metrics for this asset (with fallback to empty metrics)
            let assetMetrics = metrics[assetKey] ?? [:]

            // Create asset data directly from asset key and metrics
            let assetData = createAssetDataFromKeyAndMetrics(
                assetKey: assetKey,
                metrics: assetMetrics,
                triggeringInteractionType: triggeringInteractionType
            )

            result.append(assetData)
        }

        return result
    }

    private func createAssetDataFromKeyAndMetrics(
        assetKey: String,
        metrics: [String: Any],
        triggeringInteractionType: InteractionType
    ) -> [String: Any] {
        // Get assetURL and assetLocation directly from metrics (no parsing needed!)
        let assetURL = metrics["assetURL"] as? String ?? ""
        let assetLocation = metrics["assetLocation"] as? String ?? ""

        // Build XDM asset data structure (matching experience pattern)
        var assetData: [String: Any] = [
            "assetID": assetURL,  // Just the URL (identity)
            "assetViews": ["value": metrics["viewCount"] ?? 0],
            "assetClicks": ["value": metrics["clickCount"] ?? 0]
        ]

        // Add assetSource as dimension (like experienceSource) - empty if not provided
        if !assetLocation.isEmpty {
            assetData["assetSource"] = assetLocation
        }

        // Add assetExtras if present in metrics (stringified for XDM schema compliance)
        if let assetExtras = metrics["assetExtras"] as? [String: Any] {
            assetData["assetExtras"] = stringifyExtras(assetExtras)
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.XDM_BUILDER, "AssetID: \(assetURL) | Source: \(assetLocation.isEmpty ? "(empty)" : assetLocation)")

        return assetData
    }

    // MARK: - Experience XDM Event Creation

    func createExperienceXDMEvent(
        experienceId: String,
        interactionType: InteractionType,
        metrics: [String: Any],
        assetURLs: [String],
        experienceLocation: String?,
        state: ContentAnalyticsStateManager
    ) -> [String: Any] {
        // Use experienceLocation if provided, otherwise fallback to "mobile-app"
        let source: String
        if let location = experienceLocation, !location.isEmpty {
            source = location
        } else {
            source = "mobile-app"
        }

        var interactionData: [String: Any] = [
            "experienceID": experienceId,
            "experienceChannel": "mobile",
            "experienceSource": source
        ]

        // Add experience metrics
        if let viewCount = metrics["viewCount"] {
            interactionData["experienceViews"] = ["value": viewCount]
        }

        if let clickCount = metrics["clickCount"] {
            interactionData["experienceClicks"] = ["value": clickCount]
        }

        // Stringify experienceExtras for XDM schema compliance
        if let experienceExtras = metrics["experienceExtras"] as? [String: Any] {
            interactionData["experienceExtras"] = stringifyExtras(experienceExtras)
        }

        // Build assets array for attribution (without metrics - assets tracked separately)
        let assetsData = assetURLs.map { assetURL -> [String: Any] in
            var assetData: [String: Any] = [
                "assetID": assetURL
            ]

            // Use experienceLocation as assetSource for attribution (if available)
            if let location = experienceLocation, !location.isEmpty {
                assetData["assetSource"] = location
            } else if !experienceId.isEmpty {
                assetData["assetSource"] = experienceId
            }

            // Asset metrics (views/clicks) are tracked separately via asset events
            // Only include asset IDs here for CJA attribution
            assetData["assetViews"] = ["value": 0]
            assetData["assetClicks"] = ["value": 0]

            return assetData
        }

        var experienceContent: [String: Any] = ["experience": interactionData]

        // Assets go at root level per schema requirements
        if !assetsData.isEmpty {
            experienceContent["assets"] = assetsData
        }

        let xdmEvent = createBaseXDMEvent(experienceContent: experienceContent)

        // TRACE: Full experience interaction payload
        let hasExtras = metrics["experienceExtras"] != nil
        let summary = "ID: \(experienceId) | Type: \(interactionType.stringValue) | Assets: \(assetsData.count)"
        Log.trace(label: ContentAnalyticsConstants.LogLabels.XDM_BUILDER, "Experience INTERACTION Payload | \(summary)")

        return xdmEvent
    }
}
