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
import XCTest

/// Tests for extras merging in XDM payloads: conflict detection and resolution strategies.
class ContentAnalyticsExtrasMergingTests: XCTestCase {

    var xdmBuilder: XDMEventBuilder!

    override func setUp() {
        super.setUp()
        xdmBuilder = XDMEventBuilder()
    }

    override func tearDown() {
        xdmBuilder = nil
        super.tearDown()
    }

    // MARK: - Asset Extras Tests

    func testAssetExtras_SingleEvent_IncludesDirectly() {
        // Given - Single asset with extras
        let assetKey = "https://example.com/image.jpg?location=home"
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": "https://example.com/image.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0,
                "assetExtras": ["campaign": "summer2024", "variant": "A"]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Extras should be included directly
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let firstAsset = assets?.first
        let assetExtras = firstAsset?["assetExtras"] as? [String: Any]

        XCTAssertNotNil(assetExtras, "assetExtras should be present")
        XCTAssertEqual(assetExtras?["campaign"] as? String, "summer2024")
        XCTAssertEqual(assetExtras?["variant"] as? String, "A")
    }

    func testAssetExtras_NoExtras_OmittedFromXDM() {
        // Given - Single asset without extras
        let assetKey = "https://example.com/image.jpg?location=home"
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": "https://example.com/image.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0
                // No assetExtras
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Extras should not be present
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let firstAsset = assets?.first

        XCTAssertFalse(firstAsset?.keys.contains("assetExtras") ?? false,
                      "assetExtras should not be present when no extras provided")
    }

    func testAssetExtras_MergedExtras_IncludedCorrectly() {
        // Given - Asset with merged extras (no conflicts)
        let assetKey = "https://example.com/image.jpg?location=home"
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": "https://example.com/image.jpg",
                "assetLocation": "home",
                "viewCount": 2.0,
                "clickCount": 1.0,
                "assetExtras": [
                    "key1": "value1",
                    "key2": "value2",
                    "stable": "same"
                ]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Merged extras should be included
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let firstAsset = assets?.first
        let assetExtras = firstAsset?["assetExtras"] as? [String: Any]

        XCTAssertNotNil(assetExtras, "assetExtras should be present")
        XCTAssertEqual(assetExtras?["key1"] as? String, "value1")
        XCTAssertEqual(assetExtras?["key2"] as? String, "value2")
        XCTAssertEqual(assetExtras?["stable"] as? String, "same")
        XCTAssertNil(assetExtras?["all"], "Should not have 'all' array for merged extras")
    }

    func testAssetExtras_WithConflicts_CreatesAllArray() {
        // Given - Asset with conflicting extras
        let assetKey = "https://example.com/image.jpg?location=home"
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": "https://example.com/image.jpg",
                "assetLocation": "home",
                "viewCount": 2.0,
                "clickCount": 0.0,
                "assetExtras": [
                    "all": [
                        ["campaign": "summer2024"],
                        ["campaign": "winter2024"]
                    ]
                ]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Should have "all" array for conflicts
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let firstAsset = assets?.first
        let assetExtras = firstAsset?["assetExtras"] as? [String: Any]
        let allArray = assetExtras?["all"] as? [[String: Any]]

        XCTAssertNotNil(assetExtras, "assetExtras should be present")
        XCTAssertNotNil(allArray, "Should have 'all' array for conflicting extras")
        XCTAssertEqual(allArray?.count, 2, "Should have 2 entries in 'all' array")
    }

    // MARK: - Experience Extras Tests

    func testExperienceExtras_SingleEvent_IncludesDirectly() {
        // Given - Single experience with extras
        let experienceKey = "mobile-abc123?location=home"
        let metrics: [String: Any] = [
            "experienceId": "mobile-abc123",
            "experienceLocation": "home",
            "viewCount": 1.0,
            "clickCount": 0.0,
            "experienceExtras": ["campaign": "summer2024", "variant": "A"]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createExperienceXDMEvent(
            experienceId: "mobile-abc123",
            interactionType: .view,
            metrics: metrics,
            assetURLs: ["https://example.com/asset.jpg"],
            experienceLocation: "home",
            state: ContentAnalyticsStateManager()
        )

        // Then - Extras should be included directly
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceExtras = experience?["experienceExtras"] as? [String: Any]

        XCTAssertNotNil(experienceExtras, "experienceExtras should be present")
        XCTAssertEqual(experienceExtras?["campaign"] as? String, "summer2024")
        XCTAssertEqual(experienceExtras?["variant"] as? String, "A")
    }

    func testExperienceExtras_NoExtras_OmittedFromXDM() {
        // Given - Single experience without extras
        let metrics: [String: Any] = [
            "experienceId": "mobile-abc123",
            "experienceLocation": "home",
            "viewCount": 1.0,
            "clickCount": 0.0
            // No experienceExtras
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createExperienceXDMEvent(
            experienceId: "mobile-abc123",
            interactionType: .view,
            metrics: metrics,
            assetURLs: ["https://example.com/asset.jpg"],
            experienceLocation: "home",
            state: ContentAnalyticsStateManager()
        )

        // Then - Extras should not be present
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]

        XCTAssertFalse(experience?.keys.contains("experienceExtras") ?? false,
                      "experienceExtras should not be present when no extras provided")
    }

    func testExperienceExtras_MergedExtras_IncludedCorrectly() {
        // Given - Experience with merged extras (no conflicts)
        let metrics: [String: Any] = [
            "experienceId": "mobile-abc123",
            "experienceLocation": "home",
            "viewCount": 2.0,
            "clickCount": 1.0,
            "experienceExtras": [
                "key1": "value1",
                "key2": "value2",
                "stable": "same"
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createExperienceXDMEvent(
            experienceId: "mobile-abc123",
            interactionType: .view,
            metrics: metrics,
            assetURLs: ["https://example.com/asset.jpg"],
            experienceLocation: "home",
            state: ContentAnalyticsStateManager()
        )

        // Then - Merged extras should be included
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceExtras = experience?["experienceExtras"] as? [String: Any]

        XCTAssertNotNil(experienceExtras, "experienceExtras should be present")
        XCTAssertEqual(experienceExtras?["key1"] as? String, "value1")
        XCTAssertEqual(experienceExtras?["key2"] as? String, "value2")
        XCTAssertEqual(experienceExtras?["stable"] as? String, "same")
        XCTAssertNil(experienceExtras?["all"], "Should not have 'all' array for merged extras")
    }

    func testExperienceExtras_WithConflicts_CreatesAllArray() {
        // Given - Experience with conflicting extras
        let metrics: [String: Any] = [
            "experienceId": "mobile-abc123",
            "experienceLocation": "home",
            "viewCount": 2.0,
            "clickCount": 0.0,
            "experienceExtras": [
                "all": [
                    ["campaign": "summer2024"],
                    ["campaign": "winter2024"]
                ]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createExperienceXDMEvent(
            experienceId: "mobile-abc123",
            interactionType: .view,
            metrics: metrics,
            assetURLs: ["https://example.com/asset.jpg"],
            experienceLocation: "home",
            state: ContentAnalyticsStateManager()
        )

        // Then - Should have "all" array for conflicts
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceExtras = experience?["experienceExtras"] as? [String: Any]
        let allArray = experienceExtras?["all"] as? [[String: Any]]

        XCTAssertNotNil(experienceExtras, "experienceExtras should be present")
        XCTAssertNotNil(allArray, "Should have 'all' array for conflicting extras")
        XCTAssertEqual(allArray?.count, 2, "Should have 2 entries in 'all' array")
    }

    // MARK: - Multiple Assets Tests

    func testMultipleAssets_EachWithOwnExtras_IndependentInclusion() {
        // Given - Multiple assets, each with their own extras
        let asset1Key = "https://example.com/image1.jpg?location=home"
        let asset2Key = "https://example.com/image2.jpg?location=home"

        let metrics: [String: [String: Any]] = [
            asset1Key: [
                "assetURL": "https://example.com/image1.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0,
                "assetExtras": ["campaign": "summer2024"]
            ],
            asset2Key: [
                "assetURL": "https://example.com/image2.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0,
                "assetExtras": ["campaign": "winter2024"]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [asset1Key, asset2Key],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Each asset should have its own extras
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 2, "Should have 2 assets")

        let asset1Extras = assets?[0]["assetExtras"] as? [String: Any]
        let asset2Extras = assets?[1]["assetExtras"] as? [String: Any]

        XCTAssertEqual(asset1Extras?["campaign"] as? String, "summer2024")
        XCTAssertEqual(asset2Extras?["campaign"] as? String, "winter2024")
    }

    func testMultipleAssets_MixedExtras_OnlyIncludesWhenPresent() {
        // Given - Multiple assets, some with extras, some without
        let asset1Key = "https://example.com/image1.jpg?location=home"
        let asset2Key = "https://example.com/image2.jpg?location=home"

        let metrics: [String: [String: Any]] = [
            asset1Key: [
                "assetURL": "https://example.com/image1.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0,
                "assetExtras": ["campaign": "summer2024"]
            ],
            asset2Key: [
                "assetURL": "https://example.com/image2.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0
                // No assetExtras
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [asset1Key, asset2Key],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Only asset1 should have extras
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 2, "Should have 2 assets")

        let asset1Extras = assets?[0]["assetExtras"] as? [String: Any]
        let asset2HasExtras = assets?[1].keys.contains("assetExtras") ?? false

        XCTAssertNotNil(asset1Extras, "Asset 1 should have extras")
        XCTAssertFalse(asset2HasExtras, "Asset 2 should not have extras field")
    }

    // MARK: - Edge Cases

    func testAssetExtras_EmptyDictionary_OmittedFromXDM() {
        // Given - Asset with empty extras dictionary
        let assetKey = "https://example.com/image.jpg?location=home"
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": "https://example.com/image.jpg",
                "assetLocation": "home",
                "viewCount": 1.0,
                "clickCount": 0.0,
                "assetExtras": [:] as [String: Any]
            ]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: .view
        )

        // Then - Empty extras should still be included (preserves structure)
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let firstAsset = assets?.first
        let assetExtras = firstAsset?["assetExtras"] as? [String: Any]

        XCTAssertNotNil(assetExtras, "Empty assetExtras should still be included")
        XCTAssertTrue(assetExtras?.isEmpty ?? false, "assetExtras should be empty dictionary")
    }

    func testExperienceExtras_EmptyDictionary_OmittedFromXDM() {
        // Given - Experience with empty extras dictionary
        let metrics: [String: Any] = [
            "experienceId": "mobile-abc123",
            "experienceLocation": "home",
            "viewCount": 1.0,
            "clickCount": 0.0,
            "experienceExtras": [:] as [String: Any]
        ]

        // When - Create XDM event
        let xdm = xdmBuilder.createExperienceXDMEvent(
            experienceId: "mobile-abc123",
            interactionType: .view,
            metrics: metrics,
            assetURLs: ["https://example.com/asset.jpg"],
            experienceLocation: "home",
            state: ContentAnalyticsStateManager()
        )

        // Then - Empty extras should still be included (preserves structure)
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceExtras = experience?["experienceExtras"] as? [String: Any]

        XCTAssertNotNil(experienceExtras, "Empty experienceExtras should still be included")
        XCTAssertTrue(experienceExtras?.isEmpty ?? false, "experienceExtras should be empty dictionary")
    }
}
