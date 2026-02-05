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

/// Protocol for determining if events should be excluded based on configured patterns
protocol EventExclusionFiltering {
    /// Determines if an asset event should be excluded based on URL and location patterns
    /// - Parameter event: The asset event to check
    /// - Returns: True if the event should be excluded (not tracked)
    func shouldExcludeAsset(_ event: Event) -> Bool
    
    /// Determines if an experience event should be excluded based on location patterns
    /// - Parameter event: The experience event to check
    /// - Returns: True if the event should be excluded (not tracked)
    func shouldExcludeExperience(_ event: Event) -> Bool
}
