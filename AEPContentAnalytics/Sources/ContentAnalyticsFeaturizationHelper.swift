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

/// Container for validated featurization prerequisites
struct FeaturizationPrerequisites {
    let config: ContentAnalyticsConfiguration
    let imsOrg: String
    let definition: ExperienceDefinition
}

/// Helper enum for featurization-related operations
enum ContentAnalyticsFeaturizationHelper {

    /// Validates all prerequisites for featurization
    static func validatePrerequisites(
        experienceId: String,
        state: ContentAnalyticsStateManager,
        privacyValidator: PrivacyValidator
    ) -> FeaturizationPrerequisites? {
        // Check consent for direct HTTP calls
        guard privacyValidator.isDataCollectionAllowed() else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Skipping featurization - consent denied")
            return nil
        }

        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "✅ Privacy check passed - proceeding with featurization")

        guard let config = state.configuration else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Skipping featurization - No configuration available")
            return nil
        }

        guard let serviceUrl = config.getFeaturizationBaseUrl(),
              !serviceUrl.isEmpty else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Skipping featurization - Cannot determine URL")
            return nil
        }

        guard let imsOrg = config.experienceCloudOrgId,
              !imsOrg.isEmpty else {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Skipping featurization - IMS Org not configured")
            return nil
        }

        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "✅ Configuration valid | URL: \(serviceUrl) | Org: \(imsOrg)")

        guard let definition = state.getExperienceDefinition(for: experienceId) else {
            Log.warning(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ No definition found for experience: \(experienceId)")
            return nil
        }

        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "✅ Definition found | ID: \(experienceId) | Assets: \(definition.assets.count)")

        return FeaturizationPrerequisites(config: config, imsOrg: imsOrg, definition: definition)
    }

    /// Builds featurization content from definition
    static func buildContent(
        definition: ExperienceDefinition,
        config: ContentAnalyticsConfiguration,
        imsOrg: String,
        experienceId: String
    ) -> ExperienceContent? {
        let imagesData = definition.assets.map { assetURL -> [String: Any] in
            ["value": assetURL, "style": [:] as [String: Any]]
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
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Cannot send to featurization - datastreamId not configured")
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
    static func queueHit(
        experienceId: String,
        imsOrg: String,
        content: ExperienceContent,
        queue: PersistentHitQueue?
    ) {
        let hit = FeaturizationHit(
            experienceId: experienceId,
            imsOrg: imsOrg,
            content: content,
            timestamp: Date(),
            attemptCount: 0
        )

        guard let hitData = try? JSONEncoder().encode(hit) else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Failed to encode featurization hit | ExperienceID: \(experienceId)")
            return
        }

        Log.debug(
            label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "✅ Hit encoded | Size: \(hitData.count) bytes")

        let dataEntity = DataEntity(
            uniqueIdentifier: UUID().uuidString,
            timestamp: Date(),
            data: hitData
        )

        guard let queue = queue else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Featurization queue is nil - cannot queue hit | ID: \(experienceId)")
            return
        }

        if queue.queue(entity: dataEntity) {
            Log.debug(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "✅ Experience queued for featurization | ID: \(experienceId)")
        } else {
            Log.error(
                label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR, "❌ Failed to queue experience | ID: \(experienceId)")
        }
    }
}
