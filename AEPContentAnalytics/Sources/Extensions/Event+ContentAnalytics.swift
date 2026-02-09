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

/// Container for experience definition data extracted from events
public struct ExperienceDefinitionData {
    public let experienceId: String
    public let assets: [String]
    public let texts: [ContentItem]
    public let ctas: [ContentItem]?
}

/// Event extensions for ContentAnalytics convenience accessors
public extension Event {

    // MARK: - Event Type Detection

    /// Returns true if this is a ContentAnalytics tracking event
    var isContentAnalyticsEvent: Bool {
        type == ContentAnalyticsConstants.EventType.contentAnalytics
    }

    /// Returns true if this is an asset tracking event
    var isAssetEvent: Bool {
        name == ContentAnalyticsConstants.EventNames.TRACK_ASSET
    }

    /// Returns true if this is an experience tracking event
    var isExperienceEvent: Bool {
        name == ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE
    }

    // MARK: - Asset Event Data Accessors

    /// Asset URL from event data
    var assetURL: String? {
        data?[AssetTrackingEventPayload.RequiredFields.assetURL] as? String
    }

    /// Asset location from event data
    var assetLocation: String? {
        data?[AssetTrackingEventPayload.OptionalFields.assetLocation] as? String
    }

    /// Unified interaction type for both asset and experience events
    var interactionType: InteractionType? {
        guard let typeString = data?["interactionType"] as? String else {
            return nil
        }
        return InteractionType.from(string: typeString)
    }

    /// Additional custom data for asset events
    var assetExtras: [String: Any]? {
        data?[AssetTrackingEventPayload.OptionalFields.assetExtras] as? [String: Any]
    }

    // MARK: - Experience Event Data Accessors

    /// Experience ID from event data
    var experienceId: String? {
        data?[ExperienceTrackingEventPayload.RequiredFields.experienceId] as? String
    }

    /// Experience location from event data
    var experienceLocation: String? {
        data?[ExperienceTrackingEventPayload.OptionalFields.experienceLocation] as? String
    }

    /// Asset URLs associated with an experience
    var experienceAssetURLs: [String]? {
        data?[ExperienceTrackingEventPayload.OptionalFields.assetURLs] as? [String]
    }

    /// Text content associated with an experience (using texts key with [{value, style}] format)
    var experienceTextContent: [ContentItem]? {
        guard let textArray = data?[ExperienceTrackingEventPayload.OptionalFields.texts] as? [[String: Any]] else {
            return nil
        }
        return textArray.compactMap { ContentItem.from(dictionary: $0) }
    }

    /// Button content associated with an experience (using ctas key with [{value, style}] format)
    var experienceButtonContent: [ContentItem]? {
        guard let buttonArray = data?[ExperienceTrackingEventPayload.OptionalFields.ctas] as? [[String: Any]] else {
            return nil
        }
        return buttonArray.compactMap { ContentItem.from(dictionary: $0) }
    }

    /// Additional custom data for experience events
    var experienceExtras: [String: Any]? {
        data?[ExperienceTrackingEventPayload.OptionalFields.experienceExtras] as? [String: Any]
    }

    // MARK: - Convenience Checks

    /// Check if this is a view interaction event
    var isView: Bool {
        return interactionType == .view
    }

    /// Check if this is a click interaction event
    var isClick: Bool {
        return interactionType == .click
    }

    /// Check if this is an experience definition (registration) event
    var isExperienceDefinition: Bool {
        return interactionType == .definition
    }

    /// Extract experience definition data from event (returns nil if incomplete)
    func extractExperienceDefinitionData() -> ExperienceDefinitionData? {
        guard let experienceId = experienceId,
              let assets = experienceAssetURLs,
              let texts = experienceTextContent else {
            return nil
        }

        return ExperienceDefinitionData(
            experienceId: experienceId,
            assets: assets,
            texts: texts,
            ctas: experienceButtonContent
        )
    }

    // MARK: - Key Generation

    /// Generate asset key from event data
    var assetKey: String? {
        guard let assetURL = assetURL else { return nil }
        return ContentAnalyticsUtilities.generateAssetKey(
            assetURL: assetURL,
            assetLocation: assetLocation
        )
    }

    /// Generate experience key from event data
    var experienceKey: String? {
        guard let experienceId = experienceId else { return nil }
        return ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: experienceLocation
        )
    }
}

// MARK: - Array<Event> Extensions

extension Array where Element == Event {
    /// Count of view events in the array
    var viewCount: Int {
        return filter { $0.isView }.count
    }

    /// Count of click events in the array
    var clickCount: Int {
        return filter { $0.isClick }.count
    }

    /// Returns the interaction type of the first event, defaulting to .click if empty
    var triggeringInteractionType: InteractionType {
        return first?.interactionType ?? .click
    }

    /// Filters events to only include interactions (excludes definition events)
    var interactions: [Event] {
        return filter { !$0.isExperienceDefinition }
    }
}
