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

import AEPServices
import Foundation

/// Default configuration values
enum ContentAnalyticsDefaults {
    // MARK: - Batching Configuration

    /// Events to collect before flush (balances network efficiency vs data freshness)
    static let maxBatchSize: Int = 10

    /// Seconds between batch flushes
    static let batchFlushInterval: TimeInterval = 2.0
}

/// Configuration for ContentAnalytics extension
struct ContentAnalyticsConfiguration: Codable, Equatable {

    // MARK: - Experience Tracking Settings

    var trackExperiences: Bool = true

    // MARK: - Filtering

    var excludedAssetLocationsRegexp: String?
    var excludedAssetUrlsRegexp: String?
    var excludedExperienceLocationsRegexp: String?

    // MARK: - Adobe Configuration

    var experienceCloudOrgId: String?
    var datastreamId: String?  // Edge Network datastream ID (edge.configId)
    var edgeEnvironment: String?  // Edge environment (prod, int, etc.)
    var edgeDomain: String?  // Edge domain (can include region)
    var region: String?  // Org's home region (e.g., "va7", "irl1", "aus5", "jpn4") - for custom domains

    // MARK: - Experience Featurization Service

    /// Max retry attempts for featurization (default: 3)
    var featurizationMaxRetries: Int = 3

    /// Initial retry delay with exponential backoff (default: 0.5s → 1.0s → 2.0s)
    var featurizationRetryDelay: TimeInterval = 0.5

    // MARK: - Batching Configuration

    var batchingEnabled: Bool = true
    var maxBatchSize: Int = ContentAnalyticsDefaults.maxBatchSize
    var batchFlushInterval: TimeInterval = ContentAnalyticsDefaults.batchFlushInterval

    // MARK: - Performance Settings

    var debugLogging: Bool = false

    // MARK: - Metadata

    var version: String = ContentAnalyticsConstants.EXTENSION_VERSION
    var lastUpdated: Date = Date()
    var configurationSource: ConfigurationSource = .default

    // MARK: - Non-Codable Computed Properties

    /// Compiled asset location exclusion regex
    private(set) var compiledAssetLocationRegex: NSRegularExpression?

    /// Compiled asset URL exclusion regex
    private(set) var compiledAssetUrlRegex: NSRegularExpression?

    /// Compiled experience location exclusion regex
    private(set) var compiledExperienceLocationRegex: NSRegularExpression?

    // MARK: - Initialization

    init() {
        compileRegexPatterns()
    }

    // MARK: - URL Pattern Matching

    /// Check if a URL matches the excluded asset URLs regex
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL matches the excluded pattern
    func shouldExcludeUrl(_ url: URL) -> Bool {
        guard let regex = compiledAssetUrlRegex else { return false }
        let urlString = url.absoluteString
        let range = NSRange(urlString.startIndex..., in: urlString)
        return regex.firstMatch(in: urlString, range: range) != nil
    }

    /// Check if an asset should be excluded based on its location
    /// - Parameter location: The asset location string to check (optional)
    /// - Returns: True if the asset should be excluded
    func shouldExcludeAsset(location: String?) -> Bool {
        guard let location = location else { return false }
        // Check regex pattern
        guard let regex = compiledAssetLocationRegex else { return false }
        let range = NSRange(location.startIndex..., in: location)
        return regex.firstMatch(in: location, range: range) != nil
    }

    /// Check if an experience should be excluded based on its location
    /// - Parameter location: The experience location string to check
    /// - Returns: True if the experience should be excluded
    func shouldExcludeExperience(location: String) -> Bool {
        // Check regex pattern
        guard let regex = compiledExperienceLocationRegex else { return false }
        let range = NSRange(location.startIndex..., in: location)
        return regex.firstMatch(in: location, range: range) != nil
    }

    // MARK: - Featurization Service URL

    /// Get the effective base URL for featurization service with JAG Gateway routing
    /// Returns the base URL to use for featurization requests, including region.
    /// - Returns: The base URL string, or nil if not configured
    ///
    /// JAG Gateway URL format: https://{edgeDomain}/aca/{region}
    ///
    /// Region priority:
    /// 1. Explicit contentanalytics.region configuration (for custom domains)
    /// 2. Parse from edge.domain (for standard Adobe domains)
    /// 3. Default to "va7" (US Virginia)
    func getFeaturizationBaseUrl() -> String? {
        // Use Edge domain with /aca/{region} path (JAG Gateway routing)
        guard let domain = edgeDomain, !domain.isEmpty else {
            Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Cannot construct featurization URL - Edge domain not configured")
            return nil
        }

        // Priority 1: Explicit region configuration (for custom domains)
        // Priority 2: Parse from edge.domain (for standard domains)
        // Priority 3: Default to US
        let resolvedRegion = region ?? extractRegion(from: domain)

        let source: String
        if region != nil {
            source = "explicit config"
        } else if domain.contains("edge-") || domain.contains("adobedc.net") {
            source = "parsed from domain"
        } else {
            source = "default fallback"
        }

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Featurization URL | Domain: \(domain) | Region: \(resolvedRegion) | Source: \(source)")

        // Ensure https:// prefix
        let baseUrl = domain.hasPrefix("http") ? domain : "https://\(domain)"
        let trimmedUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return "\(trimmedUrl)/aca/\(resolvedRegion)"
    }

    /// Extract region from Edge domain (using Adobe Edge Network region codes)
    /// Reference: https://experienceleague.adobe.com/en/docs/experience-platform/landing/edge-and-hub-comparison
    ///
    /// - Parameter domain: The Edge Network domain (e.g., "edge.adobedc.net", "edge-eu.adobedc.net")
    /// - Returns: Adobe Edge Network region code string
    ///
    /// Region mapping:
    /// - Default (no region in domain) → "va7" (Virginia, US East, Platform Hub)
    /// - "edge-eu.adobedc.net" → "irl1" (Ireland, Europe)
    /// - "edge-au.adobedc.net" → "aus3" (Australia)
    /// - "edge-jp.adobedc.net" → "jpn3" (Japan)
    /// - "edge-in.adobedc.net" → "ind1" (India)
    /// - "edge-sg.adobedc.net" → "sgp3" (Singapore)
    /// - "or2" → "or2" (Oregon, US West)
    /// - "va6" → "va6" (Virginia, US East, Edge)
    private func extractRegion(from domain: String) -> String {
        let lowercasedDomain = domain.lowercased()

        // Check for region-specific domains (using Adobe Edge Network region codes)
        // Reference: https://experienceleague.adobe.com/en/docs/experience-platform/landing/edge-and-hub-comparison
        if lowercasedDomain.contains("edge-eu") || lowercasedDomain.contains("irl1") {
            return "irl1"  // Ireland (Europe)
        } else if lowercasedDomain.contains("edge-au") || lowercasedDomain.contains("aus3") {
            return "aus3"  // Australia
        } else if lowercasedDomain.contains("edge-jp") || lowercasedDomain.contains("jpn3") {
            return "jpn3"  // Japan
        } else if lowercasedDomain.contains("edge-in") || lowercasedDomain.contains("ind1") {
            return "ind1"  // India
        } else if lowercasedDomain.contains("edge-sg") || lowercasedDomain.contains("sgp3") {
            return "sgp3"  // Singapore
        } else if lowercasedDomain.contains("or2") {
            return "or2"   // Oregon (US West)
        } else if lowercasedDomain.contains("va6") {
            return "va6"   // Virginia (US East, Edge)
        } else {
            return "va7"   // Default: Virginia (US East, Platform Hub)
        }
    }

    /// Compile regex patterns into NSRegularExpression objects
    mutating func compileRegexPatterns() {
        // Compile asset location regex
        if let pattern = excludedAssetLocationsRegexp, !pattern.isEmpty {
            do {
                compiledAssetLocationRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "✅ Compiled asset location exclusion regex: \(pattern)")
            } catch {
                compiledAssetLocationRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "⚠️ Invalid asset location exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
            }
        } else {
            compiledAssetLocationRegex = nil
        }

        // Compile asset URL regex
        if let pattern = excludedAssetUrlsRegexp, !pattern.isEmpty {
            do {
                compiledAssetUrlRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "✅ Compiled asset URL exclusion regex: \(pattern)")
            } catch {
                compiledAssetUrlRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "⚠️ Invalid asset URL exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
            }
        } else {
            compiledAssetUrlRegex = nil
        }

        // Compile experience location regex
        if let pattern = excludedExperienceLocationsRegexp, !pattern.isEmpty {
            do {
                compiledExperienceLocationRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "✅ Compiled experience location exclusion regex: \(pattern)")
            } catch {
                compiledExperienceLocationRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "⚠️ Invalid experience location exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
            }
        } else {
            compiledExperienceLocationRegex = nil
        }
    }

    // MARK: - Custom Codable

    private enum CodingKeys: String, CodingKey {
        case trackExperiences
        case excludedAssetLocationsRegexp, excludedAssetUrlsRegexp
        case excludedExperienceLocationsRegexp
        case experienceCloudOrgId, datastreamId, edgeEnvironment, edgeDomain, region
        case featurizationMaxRetries, featurizationRetryDelay
        case batchingEnabled, maxBatchSize, batchFlushInterval
        case debugLogging
        case version, lastUpdated, configurationSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        trackExperiences = try container.decodeIfPresent(Bool.self, forKey: .trackExperiences) ?? true

        excludedAssetLocationsRegexp = try container.decodeIfPresent(String.self, forKey: .excludedAssetLocationsRegexp)
        excludedAssetUrlsRegexp = try container.decodeIfPresent(String.self, forKey: .excludedAssetUrlsRegexp)
        excludedExperienceLocationsRegexp = try container.decodeIfPresent(String.self, forKey: .excludedExperienceLocationsRegexp)
        experienceCloudOrgId = try container.decodeIfPresent(String.self, forKey: .experienceCloudOrgId)
        datastreamId = try container.decodeIfPresent(String.self, forKey: .datastreamId)
        edgeEnvironment = try container.decodeIfPresent(String.self, forKey: .edgeEnvironment)
        edgeDomain = try container.decodeIfPresent(String.self, forKey: .edgeDomain)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        featurizationMaxRetries = try container.decodeIfPresent(Int.self, forKey: .featurizationMaxRetries) ?? 3
        featurizationRetryDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .featurizationRetryDelay) ?? 0.5
        batchingEnabled = try container.decodeIfPresent(Bool.self, forKey: .batchingEnabled) ?? true
        maxBatchSize = try container.decodeIfPresent(Int.self, forKey: .maxBatchSize) ?? 10
        batchFlushInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .batchFlushInterval) ?? 2.0
        debugLogging = try container.decodeIfPresent(Bool.self, forKey: .debugLogging) ?? false

        version = try container.decodeIfPresent(String.self, forKey: .version) ?? ContentAnalyticsConstants.EXTENSION_VERSION
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        configurationSource = try container.decodeIfPresent(ConfigurationSource.self, forKey: .configurationSource) ?? .default

        // Compile regex patterns
        compileRegexPatterns()
    }

    // MARK: - Validation & Updates

    func validate() -> [ConfigurationValidationError] {
        return ConfigurationValidationRules().validate(self)
    }

    func applying(_ updates: [String: Any]) -> ContentAnalyticsConfiguration {
        var newConfig = self
        newConfig.lastUpdated = Date()
        newConfig.configurationSource = .runtime

        for (key, value) in updates {
            switch key {
            case "batchingEnabled":
                if let enabled = value as? Bool {
                    newConfig.batchingEnabled = enabled
                }
            case "maxBatchSize":
                if let size = value as? Int, size > 0 {
                    newConfig.maxBatchSize = min(size, 100)
                }
            case "debugLogging":
                if let debug = value as? Bool {
                    newConfig.debugLogging = debug
                }
            case "experienceCloudOrgId":
                if let orgId = value as? String, !orgId.isEmpty {
                    newConfig.experienceCloudOrgId = orgId
                }
            case "excludedAssetLocationsRegexp":
                if let pattern = value as? String, !pattern.isEmpty {
                    newConfig.excludedAssetLocationsRegexp = pattern
                }
            case "excludedAssetUrlsRegexp":
                if let pattern = value as? String, !pattern.isEmpty {
                    newConfig.excludedAssetUrlsRegexp = pattern
                }
            case "excludedExperienceLocationsRegexp":
                if let pattern = value as? String, !pattern.isEmpty {
                    newConfig.excludedExperienceLocationsRegexp = pattern
                }
            default:
                break
            }
        }

        newConfig.compileRegexPatterns()
        return newConfig
    }

    var loggingDescription: [String: Any] {
        return [
            "trackExperiences": trackExperiences,
            "batchingEnabled": batchingEnabled,
            "maxBatchSize": maxBatchSize,
            "debugLogging": debugLogging,
            "version": version,
            "lastUpdated": lastUpdated.timeIntervalSince1970,
            "source": configurationSource.rawValue
        ]
    }

    func toDictionary() -> [String: Any] {
        return [
            "trackExperiences": trackExperiences,
            "excludedAssetLocationsRegexp": excludedAssetLocationsRegexp as Any,
            "excludedAssetUrlsRegexp": excludedAssetUrlsRegexp as Any,
            "excludedExperienceLocationsRegexp": excludedExperienceLocationsRegexp as Any,
            "experienceCloudOrgId": experienceCloudOrgId as Any,
            "datastreamId": datastreamId as Any,
            "edgeEnvironment": edgeEnvironment as Any,
            "edgeDomain": edgeDomain as Any,
            "batchingEnabled": batchingEnabled,
            "maxBatchSize": maxBatchSize,
            "batchFlushInterval": batchFlushInterval,
            "debugLogging": debugLogging,
            "version": version,
            "lastUpdated": lastUpdated.timeIntervalSince1970,
            "configurationSource": configurationSource.rawValue
        ]
    }

    func toBatchingConfiguration() -> BatchingConfiguration {
        return BatchingConfiguration(
            maxBatchSize: maxBatchSize,
            flushInterval: batchFlushInterval,
            maxWaitTime: batchFlushInterval * 2.5
        )
    }
}
