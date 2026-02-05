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
import Foundation

/// Determines if events should be excluded based on configured patterns
class EventExclusionFilter: EventExclusionFiltering {
    
    private let state: ContentAnalyticsStateManager
    
    init(state: ContentAnalyticsStateManager) {
        self.state = state
    }
    
    func shouldExcludeAsset(_ event: Event) -> Bool {
        // Check URL pattern exclusion
        if let assetURL = event.assetURL, let url = URL(string: assetURL) {
            if !state.shouldTrackUrl(url) {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.EXCLUSION_FILTER, "Asset excluded by URL pattern: \(assetURL)")
                return true
            }
        }
        
        // Check location exclusion
        if !state.shouldTrackAssetLocation(event.assetLocation) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.EXCLUSION_FILTER, "Asset excluded by location pattern: \(event.assetLocation ?? "nil")")
            return true
        }
        
        return false
    }
    
    func shouldExcludeExperience(_ event: Event) -> Bool {
        let excluded = !state.shouldTrackExperience(location: event.experienceLocation)
        if excluded {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.EXCLUSION_FILTER, "Experience excluded by location pattern: \(event.experienceLocation ?? "nil")")
        }
        return excluded
    }
}
