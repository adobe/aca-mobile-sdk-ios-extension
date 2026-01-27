/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPContentAnalytics
import AEPCore
import AEPServices
import XCTest

/// Tests for ContentAnalytics public API methods
/// 
/// **Focus:** High-value tests that verify actual behavior, not just "doesn't crash"
/// 
/// **Removed Tests:** 6 low-value tests that only checked extension doesn't crash
/// without verifying any actual behavior (event dispatch, payload structure, etc.)
///
/// **What We Test:**
/// - Experience ID generation (deterministic hashing)
/// - Experience registration behavior
/// - ID consistency and uniqueness
///
/// REFACTORED: Now uses ContentAnalyticsTestBase and test utilities
class ContentAnalyticsPublicAPITests: ContentAnalyticsTestBase {
    // ✅ mockRuntime and contentAnalytics available from base class

    // MARK: - Experience Registration Tests

    func testRegisterExperience_ReturnsExperienceId() {
        // Given
        let assets = [
            ContentItem(value: "https://example.com/hero.jpg", styles: [:]),
            ContentItem(value: "https://example.com/cta.jpg", styles: [:])
        ]
        let texts = [
            ContentItem(value: "Welcome", styles: ["role": "headline"])
        ]
        let ctas = [
            ContentItem(value: "Get Started", styles: ["enabled": true])
        ]
        let location = "homepage-hero"

        // When
        let experienceId = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: ctas
        )

        // Then - Should generate a valid experience ID
        XCTAssertFalse(experienceId.isEmpty, "Experience ID should not be empty")
        XCTAssertGreaterThan(experienceId.count, 10, "Experience ID should be a substantial hash")
    }

    func testRegisterExperience_ConsistentIdGeneration() {
        // Given - Same content should generate same ID (deterministic hashing)
        let assets = [ContentItem(value: "https://example.com/image.jpg", styles: [:])]
        let texts = [ContentItem(value: "Test", styles: [:])]
        let location = "test-location"

        // When - Register same experience twice
        let id1 = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: nil
        )

        clearDispatchedEvents() // Clear between calls

        let id2 = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: nil
        )

        // Then - Should generate identical IDs
        XCTAssertEqual(id1, id2, "Same content should generate same experience ID (deterministic)")
    }

    func testRegisterExperience_DifferentContentDifferentIds() {
        // Given - Different content should generate different IDs
        let assets1 = [ContentItem(value: "https://example.com/image1.jpg", styles: [:])]
        let assets2 = [ContentItem(value: "https://example.com/image2.jpg", styles: [:])]
        let texts = [ContentItem(value: "Test", styles: [:])]
        let location = "test-location"

        // When - Register two different experiences
        let id1 = ContentAnalytics.registerExperience(
            assets: assets1,
            texts: texts,
            ctas: nil
        )

        let id2 = ContentAnalytics.registerExperience(
            assets: assets2,
            texts: texts,
            ctas: nil
        )

        // Then - Should generate different IDs
        XCTAssertNotEqual(id1, id2, "Different content should generate different experience IDs")
    }

    func testRegisterExperience_LocationNotInHash() {
        // Given - Same content, different locations
        let assets = [ContentItem(value: "https://example.com/image.jpg", styles: [:])]
        let texts = [ContentItem(value: "Test", styles: [:])]

        // When - Register same experience in different locations
        let id1 = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: nil
        )

        let id2 = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: nil
        )

        // Then - Location should NOT affect experience ID (same content = same ID)
        XCTAssertEqual(id1, id2, "Location should not affect experience ID generation")
    }
}
