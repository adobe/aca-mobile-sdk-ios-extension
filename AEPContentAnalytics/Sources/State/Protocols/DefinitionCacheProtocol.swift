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

/// Protocol for in-memory cache of experience definitions
///
/// Enables dependency injection and testing with mock implementations
protocol DefinitionCacheProtocol {
    
    /// Store a definition in cache
    /// - Parameter definition: Definition to cache
    func store(_ definition: ExperienceDefinition)
    
    /// Retrieve a definition from cache
    /// - Parameter experienceId: ID of definition to retrieve
    /// - Returns: Definition if found, nil otherwise
    func get(experienceId: String) -> ExperienceDefinition?
    
    /// Check if cache contains a definition
    /// - Parameter experienceId: ID to check
    /// - Returns: true if definition exists in cache
    func contains(experienceId: String) -> Bool
    
    /// Update an existing definition in cache
    /// - Parameter definition: Updated definition
    func update(_ definition: ExperienceDefinition)
    
    /// Get all cached definitions
    /// - Returns: Array of all definitions in cache
    func getAllDefinitions() -> [ExperienceDefinition]
    
    /// Get count of cached definitions
    var count: Int { get }
    
    /// Mark a definition as sent to featurization
    /// - Parameter experienceId: ID of definition to mark
    /// - Returns: Updated definition if found
    func markAsSent(experienceId: String) -> ExperienceDefinition?
    
    /// Check if a definition has been sent to featurization
    /// - Parameter experienceId: ID to check
    /// - Returns: true if definition has been sent
    func hasBeenSent(experienceId: String) -> Bool
    
    /// Get count of definitions that have been sent
    /// - Returns: Count of sent definitions
    func getSentCount() -> Int
    
    /// Remove all definitions from cache
    func removeAll()
}
