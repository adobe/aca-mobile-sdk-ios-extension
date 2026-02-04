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

class FeaturizationCoordinator {
    
    private let state: ContentAnalyticsStateManager
    private let privacyValidator: PrivacyValidator
    private var hitQueue: PersistentHitQueue?
    
    init(state: ContentAnalyticsStateManager, privacyValidator: PrivacyValidator) {
        self.state = state
        self.privacyValidator = privacyValidator
    }
    
    var hasQueue: Bool {
        return hitQueue != nil
    }
    
    func initializeQueue(_ queue: PersistentHitQueue?) {
        guard hitQueue == nil else {
            Log.trace(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "Featurization queue already initialized - skipping"
            )
            return
        }
        
        hitQueue = queue
        
        if hitQueue != nil {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "✅ Featurization queue ready"
            )
        } else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "Featurization queue not yet available (waiting for valid configuration)"
            )
        }
    }
    
    /// Queues an experience for featurization.
    @discardableResult
    func queueExperience(experienceId: String) -> Bool {
        guard let prerequisites = validatePrerequisites(experienceId: experienceId) else {
            return false
        }
        
        guard let content = buildContent(
            definition: prerequisites.definition,
            config: prerequisites.config,
            imsOrg: prerequisites.imsOrg,
            experienceId: experienceId
        ) else {
            return false
        }
        
        // Queue the hit
        return queueHit(
            experienceId: experienceId,
            imsOrg: prerequisites.imsOrg,
            content: content
        )
    }
    
    // MARK: - Private Helpers
    
    /// Checks consent, config, and experience definition before featurization
    private func validatePrerequisites(experienceId: String) -> FeaturizationPrerequisites? {
        guard privacyValidator.isDataCollectionAllowed() else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Skipping featurization - consent denied"
            )
            return nil
        }
        
        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
            "✅ Consent OK"
        )
        
        guard let config = state.getCurrentConfiguration() else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Skipping featurization - No configuration available"
            )
            return nil
        }
        
        guard let serviceUrl = config.getFeaturizationBaseUrl(),
              !serviceUrl.isEmpty else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Skipping featurization - Cannot determine URL"
            )
            return nil
        }
        
        guard let imsOrg = config.experienceCloudOrgId,
              !imsOrg.isEmpty else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Skipping featurization - IMS Org not configured"
            )
            return nil
        }
        
        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
            "✅ Configuration valid | URL: \(serviceUrl) | Org: \(imsOrg)"
        )
        
        guard let definition = state.getExperienceDefinition(for: experienceId) else {
            Log.warning(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ No definition found for experience: \(experienceId)"
            )
            return nil
        }
        
        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
            "✅ Definition found | ID: \(experienceId) | Assets: \(definition.assets.count)"
        )
        
        return FeaturizationPrerequisites(config: config, imsOrg: imsOrg, definition: definition)
    }
    
    /// Builds the content payload from an experience definition
    private func buildContent(
        definition: ExperienceDefinition,
        config: ContentAnalyticsConfiguration,
        imsOrg: String,
        experienceId: String
    ) -> ExperienceContent? {
        // Only include "value" for images, no empty style objects
        let imagesData = definition.assets.map { assetURL -> [String: Any] in
            ["value": assetURL]
        }
        
        let textsData = definition.texts.map { $0.toDictionary() }
        let ctasData: [[String: Any]]? = definition.ctas?.isEmpty == false ?
            definition.ctas?.map { $0.toDictionary() } : nil
        
        let contentData = ContentData(
            images: imagesData,
            texts: textsData,
            ctas: ctasData
        )
        
        guard let datastreamId = config.datastreamId, !datastreamId.isEmpty else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Cannot send to featurization - datastreamId not configured"
            )
            return nil
        }
        
        return ExperienceContent(
            content: contentData,
            orgId: imsOrg,
            datastreamId: datastreamId,
            experienceId: experienceId
        )
    }
    
    /// Encodes and queues featurization hit
    private func queueHit(
        experienceId: String,
        imsOrg: String,
        content: ExperienceContent
    ) -> Bool {
        let hit = FeaturizationHit(
            experienceId: experienceId,
            imsOrg: imsOrg,
            content: content,
            timestamp: Date(),
            attemptCount: 0
        )
        
        guard let hitData = try? JSONEncoder().encode(hit) else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Failed to encode featurization hit | ExperienceID: \(experienceId)"
            )
            return false
        }
        
        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
            "✅ Hit encoded | Size: \(hitData.count) bytes"
        )
        
        let dataEntity = DataEntity(
            uniqueIdentifier: UUID().uuidString,
            timestamp: Date(),
            data: hitData
        )
        
        guard let queue = hitQueue else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Featurization queue is nil - cannot queue hit | ID: \(experienceId)"
            )
            return false
        }
        
        if queue.queue(entity: dataEntity) {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "✅ Experience queued for featurization | ID: \(experienceId)"
            )
            return true
        } else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                "❌ Failed to queue experience | ID: \(experienceId)"
            )
            return false
        }
    }
}

/// Holds validated prerequisites needed for featurization
struct FeaturizationPrerequisites {
    let config: ContentAnalyticsConfiguration
    let imsOrg: String
    let definition: ExperienceDefinition
}
