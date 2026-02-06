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

/// Public API for ContentAnalytics extension
public extension ContentAnalytics {

    // MARK: - Core Tracking APIs

    /// Primary asset tracking method
    /// - Parameters:
    ///   - assetURL: URL of the asset being tracked
    ///   - interactionType: Type of interaction (default: .view in Swift, required in Objective-C)
    ///   - assetLocation: Semantic location identifier (optional)
    ///   - additionalData: Additional custom data (optional)
    /// - Note: In Objective-C, use AEPInteractionTypeView or AEPInteractionTypeClick for interactionType
    @objc(trackAsset:interactionType:assetLocation:additionalData:)
    static func trackAsset(
        assetURL: String,
        interactionType: InteractionType = .view,
        assetLocation: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        // Validation
        guard !assetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "trackAsset called with empty assetURL - ignoring")
            return
        }
        
        var eventData: [String: Any] = [
            AssetTrackingEventPayload.RequiredFields.assetURL: assetURL,
            AssetTrackingEventPayload.RequiredFields.interactionType: interactionType.stringValue
        ]

        if let assetLocation = assetLocation {
            eventData[AssetTrackingEventPayload.OptionalFields.assetLocation] = assetLocation
        }

        // Add additional data as assetExtras (will be mapped to XDM structure)
        if let additionalData = additionalData {
            eventData[AssetTrackingEventPayload.OptionalFields.assetExtras] = additionalData
        }

        dispatchContentAnalyticsEvent(name: ContentAnalyticsConstants.EventNames.TRACK_ASSET, data: eventData)
    }

    // MARK: - Convenience Methods

    /// Track asset view
    /// - Parameters:
    ///   - assetURL: The URL of the asset
    ///   - assetLocation: Optional semantic location identifier
    ///   - additionalData: Additional custom data (optional)
    @objc static func trackAssetView(
        assetURL: String,
        assetLocation: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        trackAsset(
            assetURL: assetURL,
            interactionType: .view,
            assetLocation: assetLocation,
            additionalData: additionalData
        )
    }

    /// Track asset click
    /// - Parameters:
    ///   - assetURL: The URL of the asset
    ///   - assetLocation: Optional semantic location identifier
    ///   - additionalData: Additional custom data (optional)
    @objc static func trackAssetClick(
        assetURL: String,
        assetLocation: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        trackAsset(
            assetURL: assetURL,
            interactionType: .click,
            assetLocation: assetLocation,
            additionalData: additionalData
        )
    }

    // MARK: - Experience Registration

    /// Register an experience using unified ContentItem structure (v2.0 API)
    /// All content types follow the consistent pattern: [{value: "", styles: {}}]
    /// 
    /// The returned experienceId is content-based (same content = same ID).
    /// Use experienceLocation in trackExperienceView/Click for location-specific analytics.
    /// 
    /// - Parameters:
    ///   - assets: Array of asset content items with value (URL) and styles
    ///   - texts: Array of text content items with value (text) and styles (role, etc.)
    ///   - ctas: Optional array of CTA/button content items with value (text) and styles (enabled, etc.)
    /// - Returns: The generated experienceId that can be used for tracking interactions
    /// - Example:
    /// ```swift
    /// let expId = ContentAnalytics.registerExperience(
    ///     assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
    ///     texts: [
    ///         ContentItem(value: "Product Title", styles: ["role": "headline"]),
    ///         ContentItem(value: "$999", styles: ["role": "price"])
    ///     ],
    ///     ctas: [ContentItem(value: "Buy Now", styles: ["enabled": true])]
    /// )
    /// // Track at specific locations
    /// ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "products/detail")
    /// ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "homepage")
    /// ```
    @discardableResult
    @objc(registerExperienceWithAssets:texts:ctas:)
    static func registerExperience(
        assets: [ContentItem],
        texts: [ContentItem],
        ctas: [ContentItem]? = nil
    ) -> String {
        // Generate experienceId from content hash
        let experienceId = ContentAnalyticsUtilities.generateExperienceId(
            from: assets,
            texts: texts,
            ctas: ctas
        )

        // Build event data
        var eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: "definition"
        ]

        eventData[ExperienceTrackingEventPayload.OptionalFields.assetURLs] = assets.map { $0.value }
        eventData[ExperienceTrackingEventPayload.OptionalFields.texts] = texts.map { $0.toDictionary() }

        if let ctas = ctas {
            eventData[ExperienceTrackingEventPayload.OptionalFields.ctas] = ctas.map { $0.toDictionary() }
        }

        dispatchContentAnalyticsEvent(name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE, data: eventData)

        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "Registered experience: \(experienceId)")

        return experienceId
    }

    /// Track experience view using a previously registered experienceId
    /// - Parameters:
    ///   - experienceId: The ID returned from registerExperience()
    ///   - experienceLocation: Location where interaction occurred. Used for analytics grouping.
    ///   - additionalData: Additional custom data to include with the view (optional)
    @objc static func trackExperienceView(
        experienceId: String,
        experienceLocation: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        // Validation
        guard !experienceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "trackExperienceView called with empty experienceId - ignoring")
            return
        }
        
        var eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: InteractionType.view.stringValue
        ]

        if let location = experienceLocation {
            eventData[ExperienceTrackingEventPayload.OptionalFields.experienceLocation] = location
        }

        // Add additional data as experienceExtras (will be mapped to XDM structure)
        if let additionalData = additionalData {
            eventData[ExperienceTrackingEventPayload.OptionalFields.experienceExtras] = additionalData
        }

        dispatchContentAnalyticsEvent(name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE, data: eventData)
    }

    /// Track experience click using a previously registered experienceId
    /// - Parameters:
    ///   - experienceId: The ID returned from registerExperience()
    ///   - experienceLocation: Location where interaction occurred. Used for analytics grouping.
    ///   - additionalData: Additional custom data to include with the click (optional)
    @objc static func trackExperienceClick(
        experienceId: String,
        experienceLocation: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        // Validation
        guard !experienceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "trackExperienceClick called with empty experienceId - ignoring")
            return
        }
        
        var eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: InteractionType.click.stringValue
        ]

        if let location = experienceLocation {
            eventData[ExperienceTrackingEventPayload.OptionalFields.experienceLocation] = location
        }

        // Add additional data as experienceExtras (will be mapped to XDM structure)
        if let additionalData = additionalData {
            eventData[ExperienceTrackingEventPayload.OptionalFields.experienceExtras] = additionalData
        }

        dispatchContentAnalyticsEvent(name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE, data: eventData)
    }

    // MARK: - Collection Tracking Methods

    /// Track multiple assets in a collection with the same interaction type
    /// - Parameters:
    ///   - assetURLs: Array of asset URLs to track
    ///   - interactionType: Type of interaction for all assets (default: .view in Swift, required in Objective-C)
    ///   - assetLocation: Optional semantic location identifier
    /// - Note: In Objective-C, use AEPInteractionTypeView or AEPInteractionTypeClick
    /// - Note: For different interaction types per asset, call trackAsset individually in a loop
    @objc(trackAssetCollection:interactionType:assetLocation:)
    static func trackAssetCollection(
        assetURLs: [String],
        interactionType: InteractionType = .view,
        assetLocation: String? = nil
    ) {
        // Validation
        guard !assetURLs.isEmpty else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "trackAssetCollection called with empty assetURLs array - ignoring")
            return
        }
        
        for assetURL in assetURLs {
            trackAsset(
                assetURL: assetURL,
                interactionType: interactionType,
                assetLocation: assetLocation
            )
        }
    }

    // MARK: - Private Helper Methods

    /// Dispatch a ContentAnalytics event to the AEP SDK
    /// Centralizes event creation
    /// - Parameters:
    ///   - name: Event name from ContentAnalyticsConstants.EventNames
    ///   - data: Event data dictionary
    private static func dispatchContentAnalyticsEvent(
        name: String,
        data: [String: Any]
    ) {
        let event = Event(
            name: name,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: data
        )
        MobileCore.dispatch(event: event)
    }
}
