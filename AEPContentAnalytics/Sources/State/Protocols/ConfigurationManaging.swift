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

/// Protocol for configuration management and validation
///
/// Enables dependency injection and testing with mock implementations
protocol ConfigurationManaging {
    
    /// Update configuration
    /// - Parameter config: New configuration to apply
    func updateConfiguration(_ config: ContentAnalyticsConfiguration)
    
    /// Get current configuration
    /// - Returns: Current configuration, or nil if not set
    func getCurrentConfiguration() -> ContentAnalyticsConfiguration?
    
    /// Check if batching is enabled
    var batchingEnabled: Bool { get }
    
    /// Check if a URL should be tracked
    /// - Parameter url: URL to validate
    /// - Returns: true if URL should be tracked
    func shouldTrackUrl(_ url: URL) -> Bool
    
    /// Check if an experience should be tracked
    /// - Parameter location: Experience location to validate
    /// - Returns: true if experience should be tracked
    func shouldTrackExperience(location: String?) -> Bool
    
    /// Check if an asset location should be tracked
    /// - Parameter location: Asset location to validate
    /// - Returns: true if asset location should be tracked
    func shouldTrackAssetLocation(_ location: String?) -> Bool
    
    /// Reset configuration to initial state
    func reset()
}
