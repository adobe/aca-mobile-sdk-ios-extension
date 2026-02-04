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
struct ExperienceDefinition: Codable {
    let experienceId: String
    let assets: [String]
    let texts: [ContentItem]
    let ctas: [ContentItem]?
    var sentToFeaturization: Bool
}

class ContentAnalyticsStateManager {

    private let stateQueue = DispatchQueue(label: "com.adobe.contentanalytics.state", qos: .userInitiated)
    private let configManager: ConfigurationManaging
    private let definitionCache: DefinitionCacheProtocol
    
    init(configManager: ConfigurationManaging = ConfigurationManager(),
         definitionCache: DefinitionCacheProtocol = DefinitionCache()) {
        self.configManager = configManager
        self.definitionCache = definitionCache
    }

    var batchingEnabled: Bool {
        return configManager.batchingEnabled
    }

    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        configManager.updateConfiguration(config)
    }

    func getCurrentConfiguration() -> ContentAnalyticsConfiguration? {
        return configManager.getCurrentConfiguration()
    }

    func shouldTrackUrl(_ url: URL) -> Bool {
        return configManager.shouldTrackUrl(url)
    }

    func shouldTrackExperience(location: String?) -> Bool {
        return configManager.shouldTrackExperience(location: location)
    }

    func shouldTrackAssetLocation(_ location: String?) -> Bool {
        return configManager.shouldTrackAssetLocation(location)
    }

    func registerExperienceDefinition(
        experienceId: String,
        assets: [String],
        texts: [ContentItem],
        ctas: [ContentItem]?
    ) {
        stateQueue.sync { [weak self] in
            let definition = ExperienceDefinition(
                experienceId: experienceId,
                assets: assets,
                texts: texts,
                ctas: ctas,
                sentToFeaturization: false
            )
            
            // Store in memory cache (handles LRU eviction if at capacity)
            self?.definitionCache.store(definition)
        }
    }

    func getExperienceDefinition(for experienceId: String) -> ExperienceDefinition? {
        return stateQueue.sync {
            if let definition = definitionCache.get(experienceId: experienceId) {
                return definition
            }
            
            Log.warning(
                label: ContentAnalyticsConstants.LogLabels.STATE_MANAGER,
                "Experience definition not found for '\(experienceId)'. " +
                "Call ContentAnalytics.trackExperience() with interactionType: .definition first."
            )
            
            return nil
        }
    }

    func hasExperienceDefinitionBeenSent(for experienceId: String) -> Bool {
        return stateQueue.sync {
            return definitionCache.get(experienceId: experienceId)?.sentToFeaturization ?? false
        }
    }

    func markExperienceDefinitionAsSent(experienceId: String) {
        stateQueue.sync {
            guard var definition = definitionCache.get(experienceId: experienceId) else {
                return
            }
            
            definition.sentToFeaturization = true
            definitionCache.update(definition)
        }
    }

    func reset() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.configManager.reset()
            self.definitionCache.removeAll()
        }
    }
}
