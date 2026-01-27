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

import Foundation
@testable import AEPContentAnalytics

/// Builder pattern for creating test data structures
/// Provides consistent, reusable test data across test suite
enum TestDataBuilder {
    
    // MARK: - ContentItem Builders
    
    /// Creates an array of test ContentItems
    /// - Parameters:
    ///   - count: Number of items to create
    ///   - prefix: Prefix for item values
    ///   - type: Type of content (asset/text/cta)
    /// - Returns: Array of ContentItem objects
    static func buildContentItems(
        count: Int,
        prefix: String = "test",
        type: ContentItemType = .asset
    ) -> [ContentItem] {
        return (0..<count).map { index in
            let value = buildContentValue(prefix: prefix, index: index, type: type)
            let styles = buildDefaultStyles(for: type)
            return ContentItem(value: value, styles: styles)
        }
    }
    
    /// Creates a single ContentItem with specific properties
    /// - Parameters:
    ///   - value: Content value
    ///   - styles: Optional styles dictionary
    ///   - type: Content type
    /// - Returns: ContentItem object
    static func buildContentItem(
        value: String,
        styles: [String: Any]? = nil,
        type: ContentItemType = .asset
    ) -> ContentItem {
        return ContentItem(
            value: value,
            styles: styles ?? buildDefaultStyles(for: type)
        )
    }
    
    // MARK: - ExperienceDefinition Builders
    
    /// Creates a test ExperienceDefinition
    /// - Parameters:
    ///   - experienceId: Unique experience ID
    ///   - assetCount: Number of assets
    ///   - textCount: Number of texts
    ///   - ctaCount: Number of CTAs
    ///   - sentToFeaturization: Whether definition was sent to ML service
    /// - Returns: ExperienceDefinition object
    static func buildExperienceDefinition(
        experienceId: String = "test-experience-id",
        assetCount: Int = 2,
        textCount: Int = 1,
        ctaCount: Int = 1,
        sentToFeaturization: Bool = false
    ) -> ExperienceDefinition {
        let assetURLs = (0..<assetCount).map { "https://example.com/asset\($0).jpg" }
        let texts = buildContentItems(count: textCount, prefix: "text", type: .text)
        let ctas = ctaCount > 0 ? buildContentItems(count: ctaCount, prefix: "cta", type: .cta) : nil
        
        return ExperienceDefinition(
            experienceId: experienceId,
            assets: assetURLs,
            texts: texts,
            ctas: ctas,
            sentToFeaturization: sentToFeaturization
        )
    }
    
    /// Creates a custom ExperienceDefinition with specific content
    /// - Parameters:
    ///   - experienceId: Unique experience ID
    ///   - assetURLs: Array of asset URL strings
    ///   - texts: Array of ContentItems for texts
    ///   - ctas: Array of ContentItems for CTAs
    ///   - sentToFeaturization: Whether definition was sent to ML service
    /// - Returns: ExperienceDefinition object
    static func buildExperienceDefinition(
        experienceId: String,
        assetURLs: [String],
        texts: [ContentItem],
        ctas: [ContentItem]?,
        sentToFeaturization: Bool = false
    ) -> ExperienceDefinition {
        return ExperienceDefinition(
            experienceId: experienceId,
            assets: assetURLs,
            texts: texts,
            ctas: ctas,
            sentToFeaturization: sentToFeaturization
        )
    }
    
    // MARK: - BatchingConfiguration Builders
    
    /// Creates a test BatchingConfiguration
    /// - Parameters:
    ///   - maxBatchSize: Maximum batch size
    ///   - flushInterval: Flush interval in seconds
    ///   - maxWaitTime: Maximum wait time in seconds
    /// - Returns: BatchingConfiguration object
    static func buildBatchingConfiguration(
        maxBatchSize: Int = 10,
        flushInterval: TimeInterval = 2.0,
        maxWaitTime: TimeInterval = 5.0
    ) -> BatchingConfiguration {
        return BatchingConfiguration(
            maxBatchSize: maxBatchSize,
            flushInterval: flushInterval,
            maxWaitTime: maxWaitTime
        )
    }
    
    // MARK: - ContentAnalyticsConfiguration Builders
    
    /// Creates a test ContentAnalyticsConfiguration
    /// - Parameters:
    ///   - batchingEnabled: Whether batching is enabled
    ///   - maxBatchSize: Maximum batch size
    ///   - batchFlushInterval: Flush interval in seconds
    ///   - excludedAssetUrlsRegexp: Asset URL regex pattern to exclude
    ///   - excludedExperienceLocationsRegexp: Experience location regex pattern to exclude
    ///   - trackExperiences: Whether to track experiences
    /// - Returns: ContentAnalyticsConfiguration object
    static func buildConfiguration(
        batchingEnabled: Bool = true,
        maxBatchSize: Int = 10,
        batchFlushInterval: TimeInterval = 2.0,
        excludedAssetUrlsRegexp: String? = nil,
        excludedExperienceLocationsRegexp: String? = nil,
        trackExperiences: Bool = true
    ) -> ContentAnalyticsConfiguration {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = batchingEnabled
        config.maxBatchSize = maxBatchSize
        config.batchFlushInterval = batchFlushInterval
        config.excludedAssetUrlsRegexp = excludedAssetUrlsRegexp
        config.excludedExperienceLocationsRegexp = excludedExperienceLocationsRegexp
        config.trackExperiences = trackExperiences
        return config
    }
    
    // MARK: - Helper Methods
    
    /// Builds a content value based on type and index
    private static func buildContentValue(
        prefix: String,
        index: Int,
        type: ContentItemType
    ) -> String {
        switch type {
        case .asset:
            return "https://example.com/\(prefix)\(index).jpg"
        case .text:
            return "\(prefix.capitalized) Text \(index)"
        case .cta:
            return "\(prefix.capitalized) CTA \(index)"
        }
    }
    
    /// Builds default styles for a content type
    private static func buildDefaultStyles(for type: ContentItemType) -> [String: Any] {
        switch type {
        case .asset:
            return ["width": 800, "height": 600]
        case .text:
            return ["role": "body", "size": "medium"]
        case .cta:
            return ["enabled": true, "variant": "primary"]
        }
    }
}

/// Content item types for test data generation
enum ContentItemType {
    case asset
    case text
    case cta
}

