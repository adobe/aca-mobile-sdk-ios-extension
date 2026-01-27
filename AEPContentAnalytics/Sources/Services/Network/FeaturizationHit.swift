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

/// Featurization request persisted to disk for retries
struct FeaturizationHit: Codable {
    let experienceId: String
    let imsOrg: String
    let content: ExperienceContent
    let timestamp: Date
    let attemptCount: Int

    init(experienceId: String, imsOrg: String, content: ExperienceContent, timestamp: Date = Date(), attemptCount: Int = 0) {
        self.experienceId = experienceId
        self.imsOrg = imsOrg
        self.content = content
        self.timestamp = timestamp
        self.attemptCount = attemptCount
    }

    /// Creates a copy with incremented attempt count (for retry tracking)
    func incrementingAttempt() -> FeaturizationHit {
        return FeaturizationHit(
            experienceId: experienceId,
            imsOrg: imsOrg,
            content: content,
            timestamp: timestamp,
            attemptCount: attemptCount + 1
        )
    }
}
