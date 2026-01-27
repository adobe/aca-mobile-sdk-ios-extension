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
import XCTest

/// Tests for utilities: key generation, experience ID hashing, and extras conflict detection.
class ContentAnalyticsUtilitiesTests: XCTestCase {

    // MARK: - Asset Key Generation Tests

    func testGenerateAssetKey_WithLocation_CombinesURLAndLocation() {
        // Given
        let assetURL = "https://example.com/image.jpg"
        let location = "homepage"

        // When
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: location)

        // Then
        XCTAssertEqual(key, "https://example.com/image.jpg?location=homepage",
                      "Should combine URL and location with ?location= separator")
    }

    func testGenerateAssetKey_WithoutLocation_ReturnsURL() {
        // Given
        let assetURL = "https://example.com/image.jpg"

        // When
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: nil)

        // Then
        XCTAssertEqual(key, assetURL, "Should return URL when location is nil")
    }

    func testGenerateAssetKey_WithEmptyLocation_ReturnsURL() {
        // Given
        let assetURL = "https://example.com/image.jpg"

        // When
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "")

        // Then
        XCTAssertEqual(key, assetURL, "Should return URL when location is empty string")
    }

    func testGenerateAssetKey_SameURLDifferentLocations_GeneratesDifferentKeys() {
        // Given
        let assetURL = "https://example.com/image.jpg"

        // When
        let key1 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "homepage")
        let key2 = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: "product-page")

        // Then
        XCTAssertNotEqual(key1, key2, "Same URL with different locations should generate different keys")
    }

    func testGenerateAssetKey_WithSpecialCharactersInLocation_HandlesCorrectly() {
        // Given
        let assetURL = "https://example.com/image.jpg"
        let location = "product/category?id=123"

        // When
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: assetURL, assetLocation: location)

        // Then
        XCTAssertTrue(key.contains(location), "Should preserve special characters in location")
    }

    // MARK: - Experience Key Generation Tests

    func testGenerateExperienceKey_WithLocation_CombinesIDAndLocation() {
        // Given
        let experienceId = "mobile-abc123def456"
        let location = "homepage"

        // When
        let key = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: location)

        // Then
        XCTAssertEqual(key, "mobile-abc123def456?location=homepage",
                      "Should combine ID and location with ?location= separator")
    }

    func testGenerateExperienceKey_WithoutLocation_ReturnsID() {
        // Given
        let experienceId = "mobile-abc123def456"

        // When
        let key = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: nil)

        // Then
        XCTAssertEqual(key, experienceId, "Should return ID when location is nil")
    }

    func testGenerateExperienceKey_WithEmptyLocation_ReturnsID() {
        // Given
        let experienceId = "mobile-abc123def456"

        // When
        let key = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: "")

        // Then
        XCTAssertEqual(key, experienceId, "Should return ID when location is empty string")
    }

    func testGenerateExperienceKey_SameIDDifferentLocations_GeneratesDifferentKeys() {
        // Given
        let experienceId = "mobile-abc123def456"

        // When
        let key1 = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: "homepage")
        let key2 = ContentAnalyticsUtilities.generateExperienceKey(experienceId: experienceId, experienceLocation: "product-page")

        // Then
        XCTAssertNotEqual(key1, key2, "Same ID with different locations should generate different keys")
    }

    // MARK: - Experience ID Generation Tests

    func testGenerateExperienceId_WithSingleAsset_GeneratesDeterministicID() {
        // Given
        let assets = [ContentItem(value: "https://example.com/image.jpg")]
        let texts = [ContentItem(value: "Welcome")]

        // When
        let id1 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)
        let id2 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)

        // Then
        XCTAssertEqual(id1, id2, "Should generate same ID for same content")
        XCTAssertTrue(id1.hasPrefix("mobile-"), "Should have mobile- prefix")
        XCTAssertEqual(id1.count, 19, "Should be 'mobile-' (7) + 12 hex chars = 19")
    }

    func testGenerateExperienceId_DifferentOrder_GeneratesSameID() {
        // Given - Same content in different order
        let assets1 = [ContentItem(value: "https://example.com/a.jpg"), ContentItem(value: "https://example.com/b.jpg")]
        let texts1 = [ContentItem(value: "Text A"), ContentItem(value: "Text B")]

        let assets2 = [ContentItem(value: "https://example.com/b.jpg"), ContentItem(value: "https://example.com/a.jpg")]
        let texts2 = [ContentItem(value: "Text B"), ContentItem(value: "Text A")]

        // When
        let id1 = ContentAnalyticsUtilities.generateExperienceId(from: assets1, texts: texts1)
        let id2 = ContentAnalyticsUtilities.generateExperienceId(from: assets2, texts: texts2)

        // Then
        XCTAssertEqual(id1, id2, "Should generate same ID regardless of content order (sorted internally)")
    }

    func testGenerateExperienceId_DifferentContent_GeneratesDifferentIDs() {
        // Given
        let assets1 = [ContentItem(value: "https://example.com/image1.jpg")]
        let texts1 = [ContentItem(value: "Welcome")]

        let assets2 = [ContentItem(value: "https://example.com/image2.jpg")]
        let texts2 = [ContentItem(value: "Welcome")]

        // When
        let id1 = ContentAnalyticsUtilities.generateExperienceId(from: assets1, texts: texts1)
        let id2 = ContentAnalyticsUtilities.generateExperienceId(from: assets2, texts: texts2)

        // Then
        XCTAssertNotEqual(id1, id2, "Different content should generate different IDs")
    }

    func testGenerateExperienceId_WithCTAs_IncludesInHash() {
        // Given
        let assets = [ContentItem(value: "https://example.com/image.jpg")]
        let texts = [ContentItem(value: "Welcome")]
        let ctas1 = [ContentItem(value: "Buy Now")]
        let ctas2 = [ContentItem(value: "Learn More")]

        // When
        let idWithCTA1 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts, ctas: ctas1)
        let idWithCTA2 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts, ctas: ctas2)
        let idWithoutCTA = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts, ctas: nil)

        // Then
        XCTAssertNotEqual(idWithCTA1, idWithCTA2, "Different CTAs should generate different IDs")
        XCTAssertNotEqual(idWithCTA1, idWithoutCTA, "With/without CTAs should generate different IDs")
    }

    func testGenerateExperienceId_WithEmptyArrays_GeneratesValidID() {
        // Given
        let assets: [ContentItem] = []
        let texts: [ContentItem] = []

        // When
        let id = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)

        // Then
        XCTAssertTrue(id.hasPrefix("mobile-"), "Should generate valid ID even with empty arrays")
        XCTAssertEqual(id.count, 19, "Should have correct length")
    }

    func testGenerateExperienceId_WithUnicodeContent_HandlesCorrectly() {
        // Given
        let assets = [ContentItem(value: "https://example.com/image.jpg")]
        let texts = [ContentItem(value: "欢迎 🎉 مرحبا")]

        // When
        let id1 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)
        let id2 = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)

        // Then
        XCTAssertEqual(id1, id2, "Should handle Unicode consistently")
        XCTAssertTrue(id1.hasPrefix("mobile-"), "Should generate valid ID with Unicode")
    }

    func testGenerateExperienceId_WithLargeContent_GeneratesValidID() {
        // Given - Large arrays
        let assets = (0..<100).map { ContentItem(value: "https://example.com/image\($0).jpg") }
        let texts = (0..<100).map { ContentItem(value: "Text \($0)") }

        // When
        let id = ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts)

        // Then
        XCTAssertTrue(id.hasPrefix("mobile-"), "Should handle large content arrays")
        XCTAssertEqual(id.count, 19, "Should maintain correct length")
    }

    func testGenerateExperienceId_HashCollisionResistance_DifferentContentGeneratesDifferentIDs() {
        // Given - Similar but different content
        let pairs = [
            (assets: [ContentItem(value: "a")], texts: [ContentItem(value: "b")]),
            (assets: [ContentItem(value: "b")], texts: [ContentItem(value: "a")]),
            (assets: [ContentItem(value: "ab")], texts: [ContentItem(value: "")]),
            (assets: [ContentItem(value: "")], texts: [ContentItem(value: "ab")])
        ]

        // When
        let ids = pairs.map { ContentAnalyticsUtilities.generateExperienceId(from: $0.assets, texts: $0.texts) }

        // Then
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, ids.count, "All different content should generate unique IDs")
    }

    // MARK: - Extras Conflict Detection Tests

    func testHasConflictingExtras_EmptyArray_ReturnsFalse() {
        // Given
        let extrasArray: [[String: Any]] = []

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Empty array should not have conflicts")
    }

    func testHasConflictingExtras_SingleDictionary_ReturnsFalse() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["key1": "value1", "key2": 42]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Single dictionary should not have conflicts")
    }

    func testHasConflictingExtras_IdenticalDictionaries_ReturnsFalse() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["key1": "value1", "key2": 42],
            ["key1": "value1", "key2": 42],
            ["key1": "value1", "key2": 42]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Identical dictionaries should not have conflicts")
    }

    func testHasConflictingExtras_DifferentKeys_ReturnsFalse() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["key1": "value1"],
            ["key2": "value2"],
            ["key3": "value3"]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Different keys should not have conflicts")
    }

    func testHasConflictingExtras_SameKeySameValue_ReturnsFalse() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["campaign": "summer2024"],
            ["campaign": "summer2024"],
            ["campaign": "summer2024"]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Same key with same value should not have conflicts")
    }

    func testHasConflictingExtras_SameKeyDifferentValues_ReturnsTrue() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["campaign": "summer2024"],
            ["campaign": "winter2024"]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertTrue(hasConflict, "Same key with different values should have conflicts")
    }

    func testHasConflictingExtras_MultipleKeysOneConflict_ReturnsTrue() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["campaign": "summer2024", "region": "US"],
            ["campaign": "winter2024", "region": "US"]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertTrue(hasConflict, "Should detect conflict even if only one key conflicts")
    }

    func testHasConflictingExtras_DifferentTypes_TreatsAsEqual() {
        // Given - Int 42 and String "42" are treated as equal when converted to string
        let extrasArray: [[String: Any]] = [
            ["value": 42],
            ["value": "42"]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertFalse(hasConflict, "Should treat Int 42 and String '42' as equal (both convert to '42')")
    }

    func testHasConflictingExtras_ComplexValues_HandlesCorrectly() {
        // Given
        let extrasArray: [[String: Any]] = [
            ["data": ["nested": "value1"]],
            ["data": ["nested": "value2"]]
        ]

        // When
        let hasConflict = ContentAnalyticsUtilities.hasConflictingExtras(extrasArray)

        // Then
        XCTAssertTrue(hasConflict, "Should detect conflicts in complex nested values")
    }

    // MARK: - Edge Case Tests

    func testGenerateKey_WithWhitespaceLocation_TreatsAsEmpty() {
        // Given
        let identifier = "test-id"
        let location = "   "

        // When
        let key = ContentAnalyticsUtilities.generateAssetKey(assetURL: identifier, assetLocation: location)

        // Then
        // Note: Current implementation doesn't trim whitespace, so this will include the location
        // This test documents the current behavior
        XCTAssertTrue(key.contains("location="), "Current implementation includes whitespace location")
    }

    func testGenerateExperienceId_Consistency_AcrossMultipleCalls() {
        // Given
        let assets = [ContentItem(value: "https://example.com/image.jpg")]
        let texts = [ContentItem(value: "Welcome")]
        let ctas = [ContentItem(value: "Buy Now")]

        // When - Generate ID 10 times
        let ids = (0..<10).map { _ in
            ContentAnalyticsUtilities.generateExperienceId(from: assets, texts: texts, ctas: ctas)
        }

        // Then - All should be identical
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, 1, "Should generate identical ID across multiple calls")
    }
}
