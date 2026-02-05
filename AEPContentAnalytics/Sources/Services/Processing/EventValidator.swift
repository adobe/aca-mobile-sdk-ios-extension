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

/// Validates event fields (URL, action type, required keys).
/// Processing conditions are checked separately by the orchestrator.
class EventValidator: EventValidating {
    
    private let state: ContentAnalyticsStateManager
    
    init(state: ContentAnalyticsStateManager) {
        self.state = state
    }
    
    func validateAssetEvent(_ event: Event) -> Result<Void, ContentAnalyticsError> {
        // Validate required fields
        guard event.assetURL != nil,
              event.interactionType != nil,
              event.assetKey != nil else {
            return .failure(.validationError("Missing required asset fields"))
        }
        
        // Validate action is view or click
        if let action = event.interactionType,
           action != InteractionType.view && action != InteractionType.click {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EVENT_VALIDATOR, "Asset event has invalid action: \(action)")
            return .failure(.validationError("Invalid action type: \(action)"))
        }
        
        return .success(())
    }
    
    func validateExperienceEvent(_ event: Event) -> Result<Void, ContentAnalyticsError> {
        // Validate required fields
        guard event.experienceId != nil,
              event.interactionType != nil else {
            return .failure(.validationError("Missing required experience fields"))
        }
        
        // Validate action is definition, view, or click
        if let action = event.interactionType,
           action != InteractionType.definition && action != InteractionType.view && action != InteractionType.click {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.EVENT_VALIDATOR, "Experience event has invalid action: \(action)")
            return .failure(.validationError("Invalid action type: \(action)"))
        }
        
        return .success(())
    }
    
    func validateProcessingConditions() -> ContentAnalyticsError? {
        // Check configuration state
        guard state.getCurrentConfiguration() != nil else {
            return .invalidConfiguration
        }
        
        return nil
    }
    
    func isExperienceTrackingEnabled() -> Bool {
        return state.getCurrentConfiguration()?.trackExperiences == true
    }
}
