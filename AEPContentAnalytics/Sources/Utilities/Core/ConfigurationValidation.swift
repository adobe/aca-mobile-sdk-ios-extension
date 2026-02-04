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

import Foundation

/// Configuration source tracking for audit and debugging
enum ConfigurationSource: String, Codable {
    case `default` = "default"
    case remoteConfig = "remote"
    case runtime = "runtime"
    case persisted = "persisted"
}

/// Configuration validation errors with detailed descriptions
enum ConfigurationValidationError: Error, CustomStringConvertible {
    case invalidBatchSize(Int)
    case invalidOrgId(String)
    case invalidUrlPattern(String)
    case invalidRequestsPerSecond(Double)

    var description: String {
        switch self {
        case .invalidBatchSize(let size):
            return "Invalid batch size: \(size). Must be between 1 and 100."
        case .invalidOrgId(let orgId):
            return "Invalid Experience Cloud Org ID: \(orgId)"
        case .invalidUrlPattern(let pattern):
            return "Invalid URL pattern: \(pattern)"
        case .invalidRequestsPerSecond(let rate):
            return "Invalid requests per second: \(rate). Must be between 0.1 and 100."
        }
    }
}

/// Configuration validation rules with comprehensive validation logic
struct ConfigurationValidationRules {

    /// Validates a configuration and returns any validation errors
    /// - Parameter config: The configuration to validate
    /// - Returns: Array of validation errors, empty if configuration is valid
    func validate(_ config: ContentAnalyticsConfiguration) -> [ConfigurationValidationError] {
        var errors: [ConfigurationValidationError] = []

        // Validate batch size
        if config.maxBatchSize < ContentAnalyticsConstants.MIN_BATCH_SIZE || config.maxBatchSize > ContentAnalyticsConstants.MAX_BATCH_SIZE {
            errors.append(.invalidBatchSize(config.maxBatchSize))
        }

        // Validate Experience Cloud Org ID format
        if let orgId = config.experienceCloudOrgId {
            if !isValidOrgId(orgId) {
                errors.append(.invalidOrgId(orgId))
            }
        }

        // Validate asset URL regex pattern
        if let pattern = config.excludedAssetUrlsRegexp, !pattern.isEmpty {
            if !isValidRegexPattern(pattern) {
                errors.append(.invalidUrlPattern(pattern))
            }
        }

        // Validate experience location regex pattern
        if let pattern = config.excludedExperienceLocationsRegexp, !pattern.isEmpty {
            if !isValidRegexPattern(pattern) {
                errors.append(.invalidUrlPattern(pattern))  // Reusing URL pattern error for regex validation
            }
        }

        return errors
    }

    /// Validates Experience Cloud Organization ID format
    /// - Parameter orgId: The organization ID to validate
    /// - Returns: true if the format is valid
    private func isValidOrgId(_ orgId: String) -> Bool {
        // Basic format validation for Experience Cloud Org ID
        let pattern = "^[A-Z0-9]{24}@AdobeOrg$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: orgId.utf16.count)
        return regex?.firstMatch(in: orgId, options: [], range: range) != nil
    }

    /// Validates that a string is a valid regular expression pattern
    /// - Parameter pattern: The regex pattern to validate
    /// - Returns: true if the pattern is valid
    private func isValidRegexPattern(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            return false
        }
    }
}
