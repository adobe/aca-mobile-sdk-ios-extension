/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPContentAnalytics
import AEPCore
import Foundation

/// Centralized factory for creating test events
/// Reduces code duplication and ensures consistent event structure across tests
enum TestEventFactory {

    // MARK: - Asset Events

    /// Creates a test asset tracking event
    /// - Parameters:
    ///   - url: Asset URL
    ///   - location: Asset location
    ///   - interaction: Interaction type (view/click)
    ///   - extras: Optional extra data
    /// - Returns: Configured asset tracking event
    static func createAssetEvent(
        url: String,
        location: String,
        interaction: InteractionType,
        extras: [String: Any]? = nil
    ) -> Event {
        var data: [String: Any] = [
            AssetTrackingEventPayload.RequiredFields.assetURL: url,
            AssetTrackingEventPayload.OptionalFields.assetLocation: location,
            AssetTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue
        ]

        if let extras = extras {
            data[AssetTrackingEventPayload.OptionalFields.assetExtras] = extras
        }

        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: data
        )
    }

    // MARK: - Experience Events

    /// Creates a test experience tracking event
    /// - Parameters:
    ///   - id: Experience ID
    ///   - location: Experience location
    ///   - interaction: Interaction type (view/click)
    ///   - assetURLs: Optional associated asset URLs
    ///   - extras: Optional extra data
    /// - Returns: Configured experience tracking event
    static func createExperienceEvent(
        id: String,
        location: String,
        interaction: InteractionType,
        assetURLs: [String]? = nil,
        extras: [String: Any]? = nil
    ) -> Event {
        var data: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: id,
            ExperienceTrackingEventPayload.OptionalFields.experienceLocation: location,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue
        ]

        if let assetURLs = assetURLs {
            data[ExperienceTrackingEventPayload.OptionalFields.assetURLs] = assetURLs
        }

        if let extras = extras {
            data[ExperienceTrackingEventPayload.OptionalFields.experienceExtras] = extras
        }

        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: data
        )
    }

    // MARK: - Configuration Events

    /// Creates a test configuration event
    /// - Parameters:
    ///   - enabled: Whether ContentAnalytics is enabled
    ///   - batchingEnabled: Whether batching is enabled
    ///   - maxBatchSize: Maximum batch size
    ///   - maxWaitTime: Maximum wait time in seconds
    ///   - excludedAssets: Assets to exclude from tracking
    ///   - shouldTrackExperience: Whether to track experiences
    /// - Returns: Configured configuration event
    static func createConfigurationEvent(
        batchingEnabled: Bool = true,
        maxBatchSize: Int = 10,
        maxWaitTime: Double = 5.0,
        excludedAssets: [String] = [],
        shouldTrackExperience: Bool = true
    ) -> Event {
        let config: [String: Any] = [
            "contentanalytics.batchingEnabled": batchingEnabled,
            "contentanalytics.maxBatchSize": maxBatchSize,
            "contentanalytics.maxWaitTime": maxWaitTime,
            "contentanalytics.excludedAssets": excludedAssets,
            "contentanalytics.shouldTrackExperience": shouldTrackExperience
        ]

        return Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        )
    }

    /// Creates a test privacy configuration event
    /// - Parameters:
    ///   - consent: Edge consent value (y/n/p)
    ///   - globalPrivacy: Legacy global privacy value
    /// - Returns: Configured configuration event with privacy settings
    static func createPrivacyConfigurationEvent(
        consent: String? = "y",
        globalPrivacy: String? = nil
    ) -> Event {
        var config: [String: Any] = [:]

        if let consent = consent {
            config["consent.default"] = [
                "consents": [
                    "collect": [
                        "val": consent
                    ]
                ]
            ]
        }

        if let globalPrivacy = globalPrivacy {
            config["global.privacy"] = globalPrivacy
        }

        return Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        )
    }

    // MARK: - Identity Events

    /// Creates a test reset identities event
    /// - Returns: Configured reset identities event
    static func createResetIdentitiesEvent() -> Event {
        return Event(
            name: "Reset Identities Request",
            type: EventType.genericIdentity,
            source: EventSource.requestReset,
            data: nil
        )
    }

    // MARK: - Invalid Event Helpers (for Validation Testing)

    /// Creates an invalid asset event missing the required assetURL field
    static func createAssetEventMissingURL(
        location: String = "home",
        interaction: InteractionType = .view
    ) -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                // Missing assetURL (REQUIRED)
                AssetTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue,
                AssetTrackingEventPayload.OptionalFields.assetLocation: location
            ]
        )
    }

    /// Creates an invalid asset event missing the required interactionType field
    static func createAssetEventMissingInteractionType(
        url: String = "https://example.com/image.jpg",
        location: String = "home"
    ) -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                AssetTrackingEventPayload.RequiredFields.assetURL: url,
                // Missing interactionType (REQUIRED)
                AssetTrackingEventPayload.OptionalFields.assetLocation: location
            ]
        )
    }

    /// Creates an invalid experience event missing the required experienceId field
    static func createExperienceEventMissingId(
        location: String = "detail",
        interaction: InteractionType = .view
    ) -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                // Missing experienceId (REQUIRED)
                ExperienceTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue,
                ExperienceTrackingEventPayload.OptionalFields.experienceLocation: location
            ]
        )
    }

    /// Creates an invalid experience event missing the required interactionType field
    static func createExperienceEventMissingInteractionType(
        id: String = "exp-123",
        location: String = "detail"
    ) -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                ExperienceTrackingEventPayload.RequiredFields.experienceId: id,
                // Missing interactionType (REQUIRED)
                ExperienceTrackingEventPayload.OptionalFields.experienceLocation: location
            ]
        )
    }

    /// Creates an event with empty data (for edge case testing)
    static func createAssetEventWithEmptyData() -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [:]
        )
    }

    /// Creates an event with nil data (for edge case testing)
    static func createAssetEventWithNilData() -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: nil
        )
    }

    // MARK: - Edge Events (for testing EdgeEventDispatcher)

    /// Creates an Edge event with XDM asset data (as dispatched by orchestrator)
    static func createEdgeAssetEvent(url: String = "https://example.com/asset.jpg") -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: [
                "xdm": [
                    "eventType": ContentAnalyticsConstants.EventType.xdmContentEngagement,
                    "experienceContent": [
                        "assets": [
                            [
                                "assetID": url,
                                "assetViews": ["value": 1],
                                "assetClicks": ["value": 0]
                            ]
                        ]
                    ]
                ]
            ]
        )
    }

    /// Creates an Edge event with XDM experience data (as dispatched by orchestrator)
    static func createEdgeExperienceEvent(id: String = "exp-123") -> Event {
        return Event(
            name: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_EXPERIENCE,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: [
                "xdm": [
                    "eventType": ContentAnalyticsConstants.EventType.xdmContentEngagement,
                    "experienceContent": [
                        "experience": [
                            "experienceID": id,
                            "experienceChannel": "mobile",
                            "experienceViews": ["value": 1],
                            "experienceClicks": ["value": 0]
                        ]
                    ]
                ]
            ]
        )
    }
}
