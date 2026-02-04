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

/// LRU cache for experience definitions
class DefinitionCache: DefinitionCacheProtocol {
    
    // MARK: - Private Properties
    
    private let cache: LRUCache<String, ExperienceDefinition>
    
    // MARK: - Initialization
    
    init(capacity: Int = ContentAnalyticsConstants.MAX_EXPERIENCE_DEFINITIONS_IN_MEMORY) {
        self.cache = LRUCache(capacity: capacity)
    }
    
    // MARK: - Definition Management
    
    func store(_ definition: ExperienceDefinition) {
        cache.set(definition, forKey: definition.experienceId)
    }
    
    func get(experienceId: String) -> ExperienceDefinition? {
        return cache.get(experienceId)
    }
    
    func contains(experienceId: String) -> Bool {
        return cache.get(experienceId) != nil
    }
    
    func update(_ definition: ExperienceDefinition) {
        cache.set(definition, forKey: definition.experienceId)
    }
    
    func getAllDefinitions() -> [ExperienceDefinition] {
        return cache.values()
    }
    
    var count: Int {
        return cache.count
    }
    
    // MARK: - Featurization Tracking
    
    @discardableResult
    func markAsSent(experienceId: String) -> ExperienceDefinition? {
        guard var definition = cache.get(experienceId) else {
            return nil
        }
        
        definition.sentToFeaturization = true
        cache.set(definition, forKey: experienceId)
        return definition
    }
    
    func hasBeenSent(experienceId: String) -> Bool {
        guard let definition = cache.get(experienceId) else {
            return false
        }
        return definition.sentToFeaturization
    }
    
    func getSentCount() -> Int {
        return cache.values().filter { $0.sentToFeaturization }.count
    }
    
    // MARK: - Reset
    
    func removeAll() {
        cache.removeAll()
    }
}
