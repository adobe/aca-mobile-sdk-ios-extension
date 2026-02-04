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
import CommonCrypto
import Foundation

/// Utility methods for image tracking calculations
enum ContentAnalyticsUtilities {

    // MARK: - Unified Key Generation

    static func generateKey(identifier: String, location: String?) -> String {
        if let location = location, !location.isEmpty {
            return "\(identifier)?location=\(location)"
        }
        return identifier
    }

    // MARK: - Asset Key Generation

    static func generateAssetKey(assetURL: String, assetLocation: String?) -> String {
        return generateKey(identifier: assetURL, location: assetLocation)
    }

    // MARK: - Experience Key Generation

    static func generateExperienceKey(experienceId: String, experienceLocation: String?) -> String {
        return generateKey(identifier: experienceId, location: experienceLocation)
    }

    // MARK: - Experience ID Generation

    static func generateExperienceId(
        from assets: [ContentItem],
        texts: [ContentItem],
        ctas: [ContentItem]? = nil
    ) -> String {
        // Sort all content arrays for deterministic hashing
        let sortedTexts = texts.map { $0.value }.sorted()
        let sortedImages = assets.map { $0.value }.sorted()
        let sortedCtas = (ctas ?? []).map { $0.value }.sorted()

        // Combine all sorted arrays into a single string for hashing
        var contentParts: [String] = []
        contentParts.append(contentsOf: sortedTexts)
        contentParts.append(contentsOf: sortedImages)
        contentParts.append(contentsOf: sortedCtas)

        let contentString = contentParts.joined(separator: "|")

        // Generate SHA-1 hash
        guard let data = contentString.data(using: .utf8) else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "Failed to generate experience ID: unable to encode content")
            return "mobile-\(Int(Date().timeIntervalSince1970))"
        }

        let hash = data.sha1().hexString()
        let shortHash = String(hash.prefix(12))

        return "mobile-\(shortHash)"
    }

    // MARK: - Extras Processing

    /// Detects if multiple extras dictionaries have conflicting values
    /// - Parameter extrasArray: Array of extras dictionaries
    /// - Returns: True if any key has different values across dictionaries
    static func hasConflictingExtras(_ extrasArray: [[String: Any]]) -> Bool {
        guard extrasArray.count > 1 else { return false }

        var keyValues: [String: [String]] = [:]

        for extras in extrasArray {
            for (key, value) in extras {
                let valueStr = "\(value)"
                keyValues[key, default: []].append(valueStr)
            }
        }

        // Check if any key has different values
        for (_, values) in keyValues where Set(values).count > 1 {
            return true
        }

        return false
    }

    /// Processes extras from multiple events, merging or creating "all" array on conflicts
    static func processExtras(
        _ extrasArray: [[String: Any]],
        for entityId: String,
        type extrasType: String
    ) -> [String: Any]? {
        guard !extrasArray.isEmpty else { return nil }

        // Single event - no conflicts
        if extrasArray.count == 1 {
            return extrasArray[0]
        }

        // Multiple events - merge and check for conflicts
        var mergedExtras: [String: Any] = [:]
        for extras in extrasArray {
            mergedExtras.merge(extras) { _, new in new }
        }

        if hasConflictingExtras(extrasArray) {
            // Conflicts detected - use "all" array only
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Detected conflicting \(extrasType) for \(entityId) - using 'all' array")
            return ["all": extrasArray]
        } else {
            // No conflicts - use merged
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "Merged \(extrasType) for \(entityId) | Events: \(extrasArray.count)")
            return mergedExtras
        }
    }
}

// MARK: - Data Extension for Hashing

private extension Data {
    /// Generate SHA-1 hash (used for experience ID generation)
    func sha1() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA1(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    /// Convert data to hex string
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
