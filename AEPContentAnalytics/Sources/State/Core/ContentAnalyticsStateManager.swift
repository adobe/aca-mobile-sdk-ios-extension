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

/// Stored experience definition for asset attribution
struct ExperienceDefinition {
    let experienceId: String
    let assets: [String]
    let texts: [ContentItem]
    let ctas: [ContentItem]?
    var sentToFeaturization: Bool
}

/// State manager for configuration and URL tracking
/// Metrics are calculated on-the-fly from PersistentQueue events
class ContentAnalyticsStateManager {

    private let stateQueue = DispatchQueue(label: "com.adobe.contentanalytics.state", qos: .userInitiated)

    /// Current configuration
    var configuration: ContentAnalyticsConfiguration?

    /// Registered experience definitions (for asset attribution and featurization tracking)
    private var experienceDefinitions: [String: ExperienceDefinition] = [:]

    // MARK: - Configuration Management

    /// Check if batching is enabled (convenience getter)
    var batchingEnabled: Bool {
        return stateQueue.sync {
            return configuration?.batchingEnabled ?? false
        }
    }

    /// Update configuration
    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        stateQueue.async { [weak self] in
            self?.configuration = config
        }
    }

    /// Get current configuration
    func getCurrentConfiguration() -> ContentAnalyticsConfiguration? {
        return stateQueue.sync {
            return configuration
        }
    }

    // MARK: - URL Exclusion

    /// Check if a URL should be tracked (not excluded by patterns)
    func shouldTrackUrl(_ url: URL) -> Bool {
        return stateQueue.sync { () -> Bool in
            guard let config = configuration else { return true }
            return !config.shouldExcludeUrl(url)
        }
    }

    /// Check if an experience location should be tracked (not excluded by patterns)
    func shouldTrackExperience(location: String?) -> Bool {
        return stateQueue.sync { () -> Bool in
            guard let config = configuration, let location = location else { return true }
            return !config.shouldExcludeExperience(location: location)
        }
    }

    /// Check if an asset location should be tracked (not excluded)
    func shouldTrackAssetLocation(_ location: String?) -> Bool {
        return stateQueue.sync { () -> Bool in
            guard let config = configuration else { return true }
            return !config.shouldExcludeAsset(location: location)
        }
    }

    // MARK: - Experience Definition Storage

    /// Store experience definition for later asset attribution
    func storeExperienceDefinition(
        experienceId: String,
        assets: [String],
        texts: [ContentItem],
        ctas: [ContentItem]?
    ) {
        stateQueue.async { [weak self] in
            let definition = ExperienceDefinition(
                experienceId: experienceId,
                assets: assets,
                texts: texts,
                ctas: ctas,
                sentToFeaturization: false
            )
            self?.experienceDefinitions[experienceId] = definition
        }
    }

    /// Retrieve stored experience definition
    func getExperienceDefinition(for experienceId: String) -> ExperienceDefinition? {
        return stateQueue.sync {
            return experienceDefinitions[experienceId]
        }
    }

    // MARK: - Featurization Tracking

    /// Check if an experience definition has been sent to featurization
    func hasExperienceDefinitionBeenSent(for experienceId: String) -> Bool {
        return stateQueue.sync {
            return experienceDefinitions[experienceId]?.sentToFeaturization ?? false
        }
    }

    /// Mark an experience definition as sent to featurization
    func markExperienceDefinitionAsSent(experienceId: String) {
        stateQueue.async { [weak self] in
            self?.experienceDefinitions[experienceId]?.sentToFeaturization = true
        }
    }

    // MARK: - Reset

    /// Clear all state
    func reset() {
        stateQueue.async { [weak self] in
            self?.configuration = nil
            self?.experienceDefinitions.removeAll()
        }
    }
}
