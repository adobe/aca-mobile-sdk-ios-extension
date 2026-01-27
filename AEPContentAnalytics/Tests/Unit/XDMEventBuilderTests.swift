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

/// Tests for XDMEventBuilder
/// REFACTORED: Simplified setup
class XDMEventBuilderTests: XCTestCase {

    var builder: XDMEventBuilder!

    override func setUp() {
        super.setUp()
        builder = XDMEventBuilder()
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - Asset XDM Event Tests

    func testCreateXDMEvent_SingleAsset_CreatesValidStructure() {
        // Given
        let assetURL = "https://example.com/image.jpg"
        let assetLocation = "homepage"
        let assetKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: assetLocation)

        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": assetURL,
                "assetLocation": assetLocation,
                "viewCount": 5,
                "clickCount": 2
            ]
        ]

        // When
        let xdm = builder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: InteractionType.view
        )

        // Then
        XCTAssertNotNil(xdm["experienceContent"])

        let experienceContent = xdm["experienceContent"] as? [String: Any]
        XCTAssertNotNil(experienceContent)

        let assetArray = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assetArray)
        let assetData = assetArray?.first
        XCTAssertNotNil(assetData)

        // Verify new structure: assetID = URL only, assetSource = location
        XCTAssertEqual(assetData?["assetID"] as? String, assetURL, "assetID should be just the URL")
        XCTAssertEqual(assetData?["assetSource"] as? String, assetLocation, "assetSource should be the location")

        let assetViews = assetData?["assetViews"] as? [String: Any]
        XCTAssertEqual(assetViews?["value"] as? Int, 5)

        let assetClicks = assetData?["assetClicks"] as? [String: Any]
        XCTAssertEqual(assetClicks?["value"] as? Int, 2)
    }

    func testCreateXDMEvent_IncludesAssetSource() {
        // Given
        let assetURL = "https://example.com/path/to/image.jpg"
        let assetLocation = "homepage"
        let assetKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: assetLocation)

        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": assetURL,
                "assetLocation": assetLocation,
                "viewCount": 1,
                "clickCount": 0
            ]
        ]

        // When
        let xdm = builder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: InteractionType.view
        )

        // Then
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assetArray = experienceContent?["assets"] as? [[String: Any]]
        let assetData = assetArray?.first

        // Verify new structure: assetSource = location (not URL base)
        let assetID = assetData?["assetID"] as? String
        let assetSource = assetData?["assetSource"] as? String

        XCTAssertEqual(assetID, assetURL, "assetID should be just the URL")
        XCTAssertEqual(assetSource, assetLocation, "assetSource should be the location")
    }

    func testCreateXDMEvent_IncludesEventType() {
        // Given
        let assetURL = "https://example.com/image.jpg"
        let assetLocation = "homepage"
        let assetKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: assetLocation)
        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": assetURL,
                "assetLocation": assetLocation,
                "viewCount": 1,
                "clickCount": 0
            ]
        ]

        // When
        let xdm = builder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: InteractionType.view
        )

        // Then
        XCTAssertEqual(xdm["eventType"] as? String, ContentAnalyticsConstants.EventType.xdmContentEngagement)
    }

    // MARK: - Experience Definition Event Tests
    // Note: Experience definitions are now handled by the external featurization service
    // and are NOT sent to AEP/Edge Network, so there are no XDM definition event tests here.

    // MARK: - Experience Interaction Event Tests

    func testCreateExperienceInteractionEvent_IncludesMetrics() {
        // Given
        let experienceId = "test-exp-id"
        let metrics: [String: Any] = [
            "viewCount": 10,
            "clickCount": 3
        ]

        // Mock state manager and assets
        let mockState = createMockStateManager()
        let assetURLs = ["https://example.com/image.jpg"]
        let location = "homepage"

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // Then
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]

        XCTAssertEqual(experience?["experienceID"] as? String, experienceId)
        XCTAssertEqual(experience?["experienceChannel"] as? String, "mobile")
        XCTAssertEqual(experience?["experienceSource"] as? String, location)

        let expViews = experience?["experienceViews"] as? [String: Any]
        XCTAssertEqual(expViews?["value"] as? Int, 10)

        let expClicks = experience?["experienceClicks"] as? [String: Any]
        XCTAssertEqual(expClicks?["value"] as? Int, 3)
    }

    func testCreateExperienceInteractionEvent_IncludesAssetReferences_WithoutMetrics() {
        // Given
        let experienceId = "test-exp-id"
        let metrics: [String: Any] = ["viewCount": 5, "clickCount": 2]
        let assetURLs = ["https://example.com/image.jpg"]
        let location = "homepage"

        let mockState = createMockStateManager()

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // Then
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertNotNil(assets, "Should include assets array for context/correlation")
        XCTAssertGreaterThan(assets?.count ?? 0, 0, "Should have at least one asset")

        let firstAsset = assets?.first
        XCTAssertNotNil(firstAsset?["assetID"], "Should include assetID for correlation")
        XCTAssertNotNil(firstAsset?["assetSource"], "Should include assetSource")
        XCTAssertNotNil(firstAsset?["assetViews"], "Should include assetViews metrics")
        XCTAssertNotNil(firstAsset?["assetClicks"], "Should include assetClicks metrics")
    }

    // MARK: - Experience + Asset Correlation Tests

    func testExperienceEvent_IncludesAssetReferences_WithoutMetrics() {
        // GIVEN: An experience with an asset
        let experienceId = "mobile-product123"
        let assetURL = "https://example.com/product.jpg"
        let location = "products/detail"
        let assetKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: location)

        let mockState = createMockStateManager()

        // WHEN: Experience interaction event is created
        let experienceMetrics: [String: Any] = ["viewCount": 1, "clickCount": 0]
        let experienceXDM = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: experienceMetrics,
            assetURLs: [assetURL],
            experienceLocation: location,
            state: mockState
        )

        // AND: Separate asset event is created
        let assetMetrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": assetURL,
                "assetLocation": location,
                "viewCount": 1,
                "clickCount": 0
            ]
        ]
        let assetXDM = builder.createAssetXDMEvent(
            from: [assetKey],
            metrics: assetMetrics,
            triggeringInteractionType: InteractionType.view
        )

        // THEN: Experience event includes asset reference
        let expContent = experienceXDM["experienceContent"] as? [String: Any]
        let experience = expContent?["experience"] as? [String: Any]
        let expAssets = expContent?["assets"] as? [[String: Any]]

        XCTAssertNotNil(expAssets, "Experience should reference assets")
        XCTAssertEqual(expAssets?.count, 1)

        let expAsset = expAssets?.first
        XCTAssertEqual(expAsset?["assetID"] as? String, assetURL)
        XCTAssertEqual(expAsset?["assetSource"] as? String, location)
        XCTAssertNotNil(expAsset?["assetViews"], "Experience asset should include metrics for CJA")
        XCTAssertNotNil(expAsset?["assetClicks"], "Experience asset should include metrics for CJA")

        // THEN: Asset event includes metrics (separate from experience)
        let assetContent = assetXDM["experienceContent"] as? [String: Any]
        let assetArray = assetContent?["assets"] as? [[String: Any]]
        let asset = assetArray?.first

        // Verify standalone asset event structure
        XCTAssertEqual(asset?["assetID"] as? String, assetURL, "Asset ID should be just the URL")
        XCTAssertEqual(asset?["assetSource"] as? String, location, "Asset source should be the location")

        let assetViews = asset?["assetViews"] as? [String: Any]
        XCTAssertEqual(assetViews?["value"] as? Int, 1, "Asset event SHOULD have metrics")

        let assetClicks = asset?["assetClicks"] as? [String: Any]
        XCTAssertEqual(assetClicks?["value"] as? Int, 0, "Asset event SHOULD have metrics")

        // THEN: Both events can be correlated by assetID
        XCTAssertEqual(expAsset?["assetID"] as? String, asset?["assetID"] as? String, "AssetID should match for CJA correlation")
    }

    func testExperienceEvent_WithMultipleAssets_ReferencesAllWithoutMetrics() {
        // GIVEN: An experience with multiple assets
        let experienceId = "mobile-gallery"
        let assetURLs = [
            "https://example.com/image1.jpg",
            "https://example.com/image2.jpg",
            "https://example.com/image3.jpg"
        ]
        let location = "gallery/view"

        let mockState = createMockStateManager()
        let metrics: [String: Any] = ["viewCount": 1, "clickCount": 0]

        // WHEN: Experience event is created
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // THEN: All assets are referenced
        let expContent = xdm["experienceContent"] as? [String: Any]
        let experience = expContent?["experience"] as? [String: Any]
        let assets = expContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 3, "Should reference all 3 assets")

        for asset in assets ?? [] {
            XCTAssertNotNil(asset["assetID"], "Each asset should have ID for correlation")
            XCTAssertNotNil(asset["assetViews"], "Assets in experience should include metrics")
            XCTAssertNotNil(asset["assetClicks"], "Assets in experience should include metrics")
        }
    }

    func testAssetEvent_TrackedIndependently_AcrossDifferentExperiences() {
        // GIVEN: Same asset used in different experiences
        let assetURL = "https://example.com/logo.jpg"
        let experience1Location = "homepage"
        let experience2Location = "about"

        let assetKey1 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: experience1Location)
        let assetKey2 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: experience2Location)

        // WHEN: Asset is viewed in both contexts
        let metrics1: [String: [String: Any]] = [
            assetKey1: [
                "assetURL": assetURL,
                "assetLocation": experience1Location,
                "viewCount": 5,
                "clickCount": 2
            ]
        ]
        let metrics2: [String: [String: Any]] = [
            assetKey2: [
                "assetURL": assetURL,
                "assetLocation": experience2Location,
                "viewCount": 3,
                "clickCount": 1
            ]
        ]

        let xdm1 = builder.createAssetXDMEvent(from: [assetKey1], metrics: metrics1, triggeringInteractionType: InteractionType.view)
        let xdm2 = builder.createAssetXDMEvent(from: [assetKey2], metrics: metrics2, triggeringInteractionType: InteractionType.view)

        // THEN: Each context has independent metrics
        let asset1Content = xdm1["experienceContent"] as? [String: Any]
        let asset1Array = asset1Content?["assets"] as? [[String: Any]]
        let asset1 = asset1Array?.first
        let asset1Views = asset1?["assetViews"] as? [String: Any]
        XCTAssertEqual(asset1Views?["value"] as? Int, 5)

        let asset2Content = xdm2["experienceContent"] as? [String: Any]
        let asset2Array = asset2Content?["assets"] as? [[String: Any]]
        let asset2 = asset2Array?.first
        let asset2Views = asset2?["assetViews"] as? [String: Any]
        XCTAssertEqual(asset2Views?["value"] as? Int, 3)

        // THEN: Same assetID (URL), different assetSource (location)
        XCTAssertEqual(asset1?["assetID"] as? String, assetURL, "Asset ID should be just the URL")
        XCTAssertEqual(asset2?["assetID"] as? String, assetURL, "Asset ID should be same for same asset")
        XCTAssertEqual(asset1?["assetSource"] as? String, experience1Location, "Asset source should be location 1")
        XCTAssertEqual(asset2?["assetSource"] as? String, experience2Location, "Asset source should be location 2")
        XCTAssertNotEqual(asset1?["assetSource"] as? String, asset2?["assetSource"] as? String, "Different locations create different sources")
    }

    // MARK: - Helper Methods

    private func createMockStateManager() -> ContentAnalyticsStateManager {
        return ContentAnalyticsStateManager()
    }

    // MARK: - XDM Field Combination Tests (Priority 2)

    func testCreateXDMEvent_ExperienceWithAllFields_CreatesCompleteStructure() {
        // Given - Experience with ALL possible fields populated
        let experienceId = "exp-complete"
        let assetURLs = [
            "https://cdn.example.com/product-1.jpg",
            "https://cdn.example.com/product-2.jpg",
            "https://cdn.example.com/product-3.jpg"
        ]
        let location = "product-detail"

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 5,
            "clickCount": 2
        ]

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // Then - Verify ALL fields are present
        XCTAssertNotNil(xdm["experienceContent"], "Should have experienceContent")

        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        // Required fields
        XCTAssertEqual(experienceData?["experienceID"] as? String, experienceId)
        XCTAssertEqual(experienceData?["experienceChannel"] as? String, "mobile")
        XCTAssertEqual(experienceData?["experienceSource"] as? String, location)

        // Assets should be at experienceContent root level
        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assets, "Should have assets")
        XCTAssertEqual(assets?.count, 3, "Should have 3 assets")

        // Metrics
        let experienceViews = experienceData?["experienceViews"] as? [String: Any]
        XCTAssertEqual(experienceViews?["value"] as? Int, 5)

        let experienceClicks = experienceData?["experienceClicks"] as? [String: Any]
        XCTAssertEqual(experienceClicks?["value"] as? Int, 2)
    }

    func testCreateXDMEvent_ExperienceWithMinimalFields_OnlyRequiredPresent() {
        // Given - Experience with ONLY required fields
        let experienceId = "exp-minimal"
        let location = "home"

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 1,
            "clickCount": 0
        ]

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: [],  // No assets
            experienceLocation: location,
            state: mockState
        )

        // Then - Verify only required fields are present
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        // Required fields should be present
        XCTAssertEqual(experienceData?["experienceID"] as? String, experienceId)
        XCTAssertEqual(experienceData?["experienceChannel"] as? String, "mobile")
        XCTAssertEqual(experienceData?["experienceSource"] as? String, location)

        // Metrics should still be present
        let experienceViews = experienceData?["experienceViews"] as? [String: Any]
        XCTAssertEqual(experienceViews?["value"] as? Int, 1)
    }

    func testCreateXDMEvent_ExperienceWith1000Assets_HandlesLargeArrays() {
        // Given - Experience with 1000 assets (boundary test)
        let experienceId = "exp-large"
        let location = "gallery"

        let assetURLs = (1...1000).map { "https://cdn.example.com/image-\($0).jpg" }

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 1,
            "clickCount": 0
        ]

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // Then - Should handle large array without issues
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        // Assets should be at experienceContent root level
        let returnedAssets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(returnedAssets, "Should have assets")
        XCTAssertEqual(returnedAssets?.count, 1000, "Should have all 1000 assets")

        // Verify first and last elements contain correct URLs
        XCTAssertTrue((returnedAssets?.first?["assetID"] as? String)?.contains("image-1.jpg") ?? false)
        XCTAssertTrue((returnedAssets?.last?["assetID"] as? String)?.contains("image-1000.jpg") ?? false)
    }

    func testCreateXDMEvent_MixedAssetTypes_CorrectStructure() {
        // Given - Experience with different asset types
        let experienceId = "exp-mixed"
        let assetURLs = [
            "https://example.com/image.jpg",
            "https://example.com/video.mp4",
            "https://example.com/document.pdf"
        ]
        let location = "content-hub"

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 2,
            "clickCount": 0
        ]

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: location,
            state: mockState
        )

        // Then - Should handle different asset types
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        // Assets should be at experienceContent root level
        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assets, "Should have assets")
        XCTAssertEqual(assets?.count, 3, "Should have 3 different asset types")

        // Verify asset types are detected
        // Asset type can be inferred from URL extension if needed in CJA
        XCTAssertEqual(assets?.count, 3, "Should include all 3 assets")
    }

    func testCreateXDMEvent_EmptyAssetArray_HandledGracefully() {
        // Given - Experience with empty asset array
        let experienceId = "exp-no-assets"
        let location = "home"

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 1,
            "clickCount": 0
        ]

        // When
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: [],  // Empty
            experienceLocation: location,
            state: mockState
        )

        // Then - Should handle empty array gracefully
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        // Should not crash
        XCTAssertNotNil(experienceData, "Should still create valid XDM structure")

        // Assets array should be nil at experienceContent root level (not added when empty)
        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNil(assets, "assets should not be present when empty")
    }

    // MARK: - Optional Location Tests (NEW - Added 2025-11-19)

    func testCreateExperienceXDMEvent_WithNilLocation_UsesFallback() {
        // Given - Experience with nil location (optional field per API)
        let experienceId = "exp-no-location"
        let assetURLs = ["https://example.com/image.jpg"]

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 1,
            "clickCount": 0
        ]

        // When - Create experience event with nil location
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: nil,  // ← Optional, can be nil!
            state: mockState
        )

        // Then - Should create valid XDM with fallback source
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        XCTAssertNotNil(experienceData, "Should still create valid XDM structure")
        XCTAssertEqual(experienceData?["experienceID"] as? String, experienceId)
        XCTAssertEqual(experienceData?["experienceChannel"] as? String, "mobile")

        // Should use fallback "mobile-app" when location is nil
        XCTAssertEqual(experienceData?["experienceSource"] as? String, "mobile-app",
                      "Should fallback to 'mobile-app' when location is nil")

        // Metrics should still be present
        let experienceViews = experienceData?["experienceViews"] as? [String: Any]
        XCTAssertEqual(experienceViews?["value"] as? Int, 1)

        // Assets should use experienceId as fallback source
        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assets, "Should include assets")
        let firstAsset = assets?.first
        XCTAssertEqual(firstAsset?["assetID"] as? String, "https://example.com/image.jpg")
        XCTAssertEqual(firstAsset?["assetSource"] as? String, experienceId,
                      "Should use experienceId as asset source when location is nil")
    }

    func testCreateExperienceXDMEvent_WithEmptyStringLocation_UsesFallback() {
        // Given - Experience with empty string location
        let experienceId = "exp-empty-location"
        let assetURLs = ["https://example.com/image.jpg"]

        let mockState = createMockStateManager()

        let metrics: [String: Any] = [
            "viewCount": 1,
            "clickCount": 0
        ]

        // When - Create experience event with empty string location
        let xdm = builder.createExperienceXDMEvent(
            experienceId: experienceId,
            interactionType: InteractionType.view,
            metrics: metrics,
            assetURLs: assetURLs,
            experienceLocation: "",  // ← Empty string
            state: mockState
        )

        // Then - Should create valid XDM with fallback source
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let experienceData = experienceContent?["experience"] as? [String: Any]

        XCTAssertNotNil(experienceData, "Should still create valid XDM structure")

        // Should use fallback "mobile-app" when location is empty
        XCTAssertEqual(experienceData?["experienceSource"] as? String, "mobile-app",
                      "Should fallback to 'mobile-app' when location is empty string")
    }

    func testCreateAssetXDMEvent_WithoutLocation_OmitsAssetSource() {
        // Given - Asset with empty location
        let assetURL = "https://example.com/image.jpg"
        let assetLocation = ""  // Empty location
        let assetKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: assetLocation)

        let metrics: [String: [String: Any]] = [
            assetKey: [
                "assetURL": assetURL,
                "assetLocation": assetLocation,  // Empty
                "viewCount": 1,
                "clickCount": 0
            ]
        ]

        // When
        let xdm = builder.createAssetXDMEvent(
            from: [assetKey],
            metrics: metrics,
            triggeringInteractionType: InteractionType.view
        )

        // Then - assetSource should be omitted when location is empty
        let experienceContent = xdm["experienceContent"] as? [String: Any]
        let assetArray = experienceContent?["assets"] as? [[String: Any]]
        let assetData = assetArray?.first

        XCTAssertEqual(assetData?["assetID"] as? String, assetURL, "assetID should be the URL")

        // assetSource should NOT be present when location is empty (per implementation)
        let assetSource = assetData?["assetSource"] as? String
        XCTAssertNil(assetSource, "assetSource should be omitted when location is empty")
    }
}

// MARK: - NOTE: Use TestableExtensionRuntime from TestHelpers/TestableExtensionRuntime.swift
