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
import Foundation

/// Protocol for validating Content Analytics events before processing
protocol EventValidating {
    /// Validates an asset tracking event
    /// - Parameter event: The asset event to validate
    /// - Returns: Success if valid, or a ContentAnalyticsError describing the validation failure
    func validateAssetEvent(_ event: Event) -> Result<Void, ContentAnalyticsError>
    
    /// Validates an experience tracking event
    /// - Parameter event: The experience event to validate
    /// - Returns: Success if valid, or a ContentAnalyticsError describing the validation failure
    func validateExperienceEvent(_ event: Event) -> Result<Void, ContentAnalyticsError>
    
    /// Validates common processing conditions (configuration state)
    /// - Returns: An error if conditions are not met, nil otherwise
    func validateProcessingConditions() -> ContentAnalyticsError?
    
    /// Returns true if experience tracking is enabled in configuration
    func isExperienceTrackingEnabled() -> Bool
}
