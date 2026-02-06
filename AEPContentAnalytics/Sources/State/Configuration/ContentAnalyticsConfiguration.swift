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
    static let maxBatchSize: Int = ContentAnalyticsConstants.DEFAULT_BATCH_SIZE

    /// Seconds between batch flushes
    static let batchFlushInterval: TimeInterval = ContentAnalyticsConstants.DEFAULT_FLUSH_INTERVAL
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
    var edgeEnvironment: String?
    var edgeDomain: String?
    var region: String?

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

    func getFeaturizationBaseUrl() -> String? {
        guard let domain = edgeDomain, !domain.isEmpty else {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Cannot construct featurization URL - Edge domain not configured")
            return nil
        }

        let resolvedRegion = region ?? extractRegion(from: domain)

        let source: String
        if region != nil {
            source = "explicit config"
        } else if domain.contains("edge-") || domain.contains("adobedc.net") {
            source = "parsed from domain"
        } else {
            source = "default fallback"
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Featurization URL | Domain: \(domain) | Region: \(resolvedRegion) | Source: \(source)")

        // Ensure https:// prefix
        let baseUrl = domain.hasPrefix("http") ? domain : "https://\(domain)"
        let trimmedUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return "\(trimmedUrl)/aca/\(resolvedRegion)"
    }

    private func extractRegion(from domain: String) -> String {
        let lowercasedDomain = domain.lowercased()

        if lowercasedDomain.contains("edge-eu") || lowercasedDomain.contains("irl1") {
            return "irl1"
        } else if lowercasedDomain.contains("edge-au") || lowercasedDomain.contains("aus3") {
            return "aus3"
        } else if lowercasedDomain.contains("edge-jp") || lowercasedDomain.contains("jpn3") {
            return "jpn3"
        } else if lowercasedDomain.contains("edge-in") || lowercasedDomain.contains("ind1") {
            return "ind1"
        } else if lowercasedDomain.contains("edge-sg") || lowercasedDomain.contains("sgp3") {
            return "sgp3"
        } else if lowercasedDomain.contains("or2") {
            return "or2"
        } else if lowercasedDomain.contains("va6") {
            return "va6"
        } else {
            return "va7"
        }
    }

    mutating func compileRegexPatterns() {
        if let pattern = excludedAssetLocationsRegexp, !pattern.isEmpty {
            do {
                compiledAssetLocationRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Compiled asset location exclusion regex: \(pattern)")
            } catch {
                compiledAssetLocationRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Invalid asset location exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
            }
        } else {
            compiledAssetLocationRegex = nil
        }

        if let pattern = excludedAssetUrlsRegexp, !pattern.isEmpty {
            do {
                compiledAssetUrlRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Compiled asset URL exclusion regex: \(pattern)")
            } catch {
                compiledAssetUrlRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Invalid asset URL exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
            }
        } else {
            compiledAssetUrlRegex = nil
        }

        if let pattern = excludedExperienceLocationsRegexp, !pattern.isEmpty {
            do {
                compiledExperienceLocationRegex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                Log.debug(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Compiled experience location exclusion regex: \(pattern)")
            } catch {
                compiledExperienceLocationRegex = nil
                Log.warning(label: ContentAnalyticsConstants.LogLabels.CONFIG, "Invalid experience location exclusion regex: '\(pattern)' - Error: \(error.localizedDescription)")
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
        maxBatchSize = try container.decodeIfPresent(Int.self, forKey: .maxBatchSize) ?? ContentAnalyticsConstants.DEFAULT_BATCH_SIZE
        batchFlushInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .batchFlushInterval) ?? ContentAnalyticsConstants.DEFAULT_FLUSH_INTERVAL
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
                    newConfig.maxBatchSize = min(size, ContentAnalyticsConstants.MAX_BATCH_SIZE)
                }
            case "batchFlushInterval":
                if let interval = value as? TimeInterval, interval > 0 {
                    newConfig.batchFlushInterval = interval
                } else if let number = value as? NSNumber, number.doubleValue > 0 {
                    newConfig.batchFlushInterval = number.doubleValue
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
            maxWaitTime: batchFlushInterval * ContentAnalyticsConstants.MAX_WAIT_TIME_MULTIPLIER
        )
    }
}
