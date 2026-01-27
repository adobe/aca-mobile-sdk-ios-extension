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

import XCTest
@testable import AEPContentAnalytics

/// Tests verifying location-based key generation for assets and experiences
class ContentAnalyticsLocationKeyGenerationTests: XCTestCase {
    
    // MARK: - Asset Key Generation Tests
    
    func testAssetKey_WithLocation_IncludesLocation() {
        let assetURL = "https://example.com/banner.jpg"
        let location = "home"
        
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: location)
        
        XCTAssertEqual(key, "https://example.com/banner.jpg?location=home")
    }
    
    func testAssetKey_WithoutLocation_ReturnsURLOnly() {
        let assetURL = "https://example.com/banner.jpg"
        
        let keyWithNil = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: nil)
        let keyWithEmpty = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "")
        
        XCTAssertEqual(keyWithNil, assetURL)
        XCTAssertEqual(keyWithEmpty, assetURL)
    }
    
    func testAssetKey_SameAssetDifferentLocations_GeneratesDifferentKeys() {
        let assetURL = "https://example.com/banner.jpg"
        
        let homeKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "home")
        let productKey = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "product")
        
        XCTAssertNotEqual(homeKey, productKey, "Same asset on different pages should have different keys")
        XCTAssertTrue(homeKey.contains("home"))
        XCTAssertTrue(productKey.contains("product"))
    }
    
    // MARK: - Experience Key Generation Tests
    
    func testExperienceKey_WithLocation_IncludesLocation() {
        let experienceId = "mobile-abc123"
        let location = "home"
        
        let key = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: location
        )
        
        XCTAssertEqual(key, "mobile-abc123?location=home")
    }
    
    func testExperienceKey_WithoutLocation_ReturnsIdOnly() {
        let experienceId = "mobile-abc123"
        
        let keyWithNil = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: nil
        )
        let keyWithEmpty = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: ""
        )
        
        XCTAssertEqual(keyWithNil, experienceId)
        XCTAssertEqual(keyWithEmpty, experienceId)
    }
    
    func testExperienceKey_SameContentDifferentLocations_GeneratesDifferentKeys() {
        let experienceId = "mobile-abc123"
        
        let homeKey = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: "home"
        )
        let productKey = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: "product"
        )
        
        XCTAssertNotEqual(homeKey, productKey, "Same experience on different pages should have different keys")
        XCTAssertTrue(homeKey.contains("home"))
        XCTAssertTrue(productKey.contains("product"))
    }
    
    // MARK: - Experience ID vs Key Tests
    
    func testExperienceId_SameContentDifferentLocations_GeneratesSameId() {
        let assets = [ContentItem(value: "https://example.com/hero.jpg", styles: [:])]
        let texts = [ContentItem(value: "Welcome", styles: [:])]
        
        let idHome = ContentAnalyticsUtilities.generateExperienceId(
            from: assets,
            texts: texts,
            ctas: nil
        )
        
        let idProduct = ContentAnalyticsUtilities.generateExperienceId(
            from: assets,
            texts: texts,
            ctas: nil
        )
        
        // Same content should generate same ID (location not in hash - for featurization deduplication)
        XCTAssertEqual(idHome, idProduct, "Same content should generate same experienceId regardless of location")
    }
    
    func testExperienceKeyIncludesId_ForFeaturizationDeduplication() {
        // Verify that experience key starts with experienceId
        // This ensures featurization can still deduplicate based on ID
        
        let assets = [ContentItem(value: "https://example.com/hero.jpg", styles: [:])]
        let texts = [ContentItem(value: "Welcome", styles: [:])]
        let experienceId = ContentAnalyticsUtilities.generateExperienceId(
            from: assets,
            texts: texts,
            ctas: nil,
        )
        
        let keyHome = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: "home"
        )
        let keyProduct = ContentAnalyticsUtilities.generateExperienceKey(
            experienceId: experienceId,
            experienceLocation: "product"
        )
        
        // Both keys should start with experienceId
        XCTAssertTrue(keyHome.hasPrefix(experienceId), "Experience key should start with experienceId")
        XCTAssertTrue(keyProduct.hasPrefix(experienceId), "Experience key should start with experienceId")
        
        // But keys should be different (for separate metrics tracking)
        XCTAssertNotEqual(keyHome, keyProduct)
    }
    
    // MARK: - Consistency Between Assets and Experiences
    
    func testLocationBasedTracking_AssetsAndExperiences_BehaveConsistently() {
        // Both should use location in key generation
        let assetURL = "https://example.com/banner.jpg"
        let assetKey1 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "home")
        let assetKey2 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "product")
        let assetKeyNoLoc = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: nil)
        
        let experienceId = "mobile-abc123"
        let expKey1 = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: "home")
        let expKey2 = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: "product")
        let expKeyNoLoc = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: nil)
        
        // Both should include location in key when provided
        XCTAssertTrue(assetKey1.contains("home"), "Asset key should include location")
        XCTAssertTrue(assetKey2.contains("product"), "Asset key should include location")
        XCTAssertTrue(expKey1.contains("home"), "Experience key should include location")
        XCTAssertTrue(expKey2.contains("product"), "Experience key should include location")
        
        // Keys should differ by location
        XCTAssertNotEqual(assetKey1, assetKey2, "Different locations = different asset keys")
        XCTAssertNotEqual(expKey1, expKey2, "Different locations = different experience keys")
        
        // Without location, should return base identifier
        XCTAssertEqual(assetKeyNoLoc, assetURL, "No location = asset URL only")
        XCTAssertEqual(expKeyNoLoc, experienceId, "No location = experienceId only")
    }
}

