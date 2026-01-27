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

/// Tests for state manager: configuration updates, experience definitions, exclusion patterns, and thread safety.
class ContentAnalyticsStateManagerTests: XCTestCase {
    
    var stateManager: ContentAnalyticsStateManager!
    
    override func setUp() {
        super.setUp()
        stateManager = ContentAnalyticsStateManager()
    }
    
    override func tearDown() {
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Create a test configuration
    private func createTestConfiguration(
        batchingEnabled: Bool = true,
        excludedAssetUrlsRegexp: String? = nil,
        excludedExperienceLocationsRegexp: String? = nil
    ) -> ContentAnalyticsConfiguration {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = batchingEnabled
        config.excludedAssetUrlsRegexp = excludedAssetUrlsRegexp
        config.excludedExperienceLocationsRegexp = excludedExperienceLocationsRegexp
        // Note: compileUrlPatterns() and compileExperienceLocationPatterns() are called in init()
        // and when patterns are set, so no need to call them explicitly
        return config
    }
    
    // MARK: - Configuration Management Tests
    
    func testUpdateConfiguration_ValidConfig_UpdatesState() {
        // Given
        let config = createTestConfiguration(batchingEnabled: true)
        
        // When
        stateManager.updateConfiguration(config)
        
        // Wait for async update
        let expectation = XCTestExpectation(description: "Config updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let retrievedConfig = stateManager.getCurrentConfiguration()
        XCTAssertNotNil(retrievedConfig, "Configuration should be stored")
        XCTAssertTrue(retrievedConfig?.batchingEnabled ?? false)
    }
    
    func testGetCurrentConfiguration_BeforeUpdate_ReturnsNil() {
        // When
        let config = stateManager.getCurrentConfiguration()
        
        // Then
        XCTAssertNil(config, "Configuration should be nil before any update")
    }
    
    func testGetCurrentConfiguration_AfterMultipleUpdates_ReturnsLatest() {
        // Given
        let config1 = createTestConfiguration(batchingEnabled: true)
        let config2 = createTestConfiguration(batchingEnabled: false)
        let config3 = createTestConfiguration(batchingEnabled: true)
        
        // When
        stateManager.updateConfiguration(config1)
        stateManager.updateConfiguration(config2)
        stateManager.updateConfiguration(config3)
        
        // Wait for async updates
        let expectation = XCTestExpectation(description: "All configs updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let retrievedConfig = stateManager.getCurrentConfiguration()
        XCTAssertTrue(retrievedConfig?.batchingEnabled ?? false, "Should return latest configuration")
    }
    
    func testBatchingEnabled_WhenConfigured_ReturnsCorrectValue() {
        // Given
        let config = createTestConfiguration(batchingEnabled: true)
        stateManager.updateConfiguration(config)
        
        // Wait for async update
        let expectation = XCTestExpectation(description: "Config updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let enabled = stateManager.batchingEnabled
        
        // Then
        XCTAssertTrue(enabled, "Should return true when batching enabled")
    }
    
    func testBatchingEnabled_WhenNotConfigured_ReturnsFalse() {
        // When
        let enabled = stateManager.batchingEnabled
        
        // Then
        XCTAssertFalse(enabled, "Should return false when no configuration")
    }
    
    // MARK: - Experience Definition Storage Tests
    
    func testStoreExperienceDefinition_NewExperience_StoresSuccessfully() {
        // Given
        let experienceId = "exp-123"
        let assets = ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
        let texts = [ContentItem(value: "Title")]
        let ctas = [ContentItem(value: "Click Here")]
        
        // When
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: assets,
            texts: texts,
            ctas: ctas
        )
        
        // Wait for async storage
        let expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let definition = stateManager.getExperienceDefinition(for: experienceId)
        XCTAssertNotNil(definition, "Definition should be stored")
        XCTAssertEqual(definition?.experienceId, experienceId)
        XCTAssertEqual(definition?.assets.count, 2)
        XCTAssertEqual(definition?.texts.count, 1)
        XCTAssertEqual(definition?.ctas?.count, 1)
        XCTAssertFalse(definition?.sentToFeaturization ?? true, "Should not be marked as sent initially")
    }
    
    func testGetExperienceDefinition_ExistingId_ReturnsDefinition() {
        // Given
        let experienceId = "exp-456"
        let assets = ["https://example.com/asset.jpg"]
        let texts = [ContentItem(value: "Text")]
        
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: assets,
            texts: texts,
            ctas: nil
        )
        
        // Wait for async storage
        let expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let definition = stateManager.getExperienceDefinition(for: experienceId)
        
        // Then
        XCTAssertNotNil(definition)
        XCTAssertEqual(definition?.experienceId, experienceId)
        XCTAssertEqual(definition?.assets, assets)
        XCTAssertEqual(definition?.texts.count, 1)
        XCTAssertNil(definition?.ctas)
    }
    
    func testGetExperienceDefinition_NonExistentId_ReturnsNil() {
        // When
        let definition = stateManager.getExperienceDefinition(for: "non-existent-id")
        
        // Then
        XCTAssertNil(definition, "Should return nil for non-existent experience")
    }
    
    func testStoreExperienceDefinition_DuplicateId_UpdatesExisting() {
        // Given
        let experienceId = "exp-789"
        let initialAssets = ["https://example.com/old.jpg"]
        let updatedAssets = ["https://example.com/new1.jpg", "https://example.com/new2.jpg"]
        let texts = [ContentItem(value: "Text")]
        
        // Store initial
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: initialAssets,
            texts: texts,
            ctas: nil
        )
        
        // Wait for async storage
        var expectation = XCTestExpectation(description: "Initial stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When - Store updated
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: updatedAssets,
            texts: texts,
            ctas: nil
        )
        
        // Wait for async update
        expectation = XCTestExpectation(description: "Update stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let definition = stateManager.getExperienceDefinition(for: experienceId)
        XCTAssertEqual(definition?.assets.count, 2, "Should update to new assets")
        XCTAssertEqual(definition?.assets, updatedAssets)
    }
    
    func testStoreExperienceDefinition_EmptyAssets_HandlesGracefully() {
        // Given
        let experienceId = "exp-empty"
        let texts = [ContentItem(value: "Text")]
        
        // When
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: [],
            texts: texts,
            ctas: nil
        )
        
        // Wait for async storage
        let expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let definition = stateManager.getExperienceDefinition(for: experienceId)
        XCTAssertNotNil(definition, "Should store even with empty assets")
        XCTAssertTrue(definition?.assets.isEmpty ?? false)
    }
    
    func testStoreExperienceDefinition_LargeVolume_HandlesGracefully() {
        // Given - Store 100 experiences
        let experienceCount = 100
        
        // When
        for i in 0..<experienceCount {
            stateManager.storeExperienceDefinition(
                experienceId: "exp-\(i)",
                assets: ["https://example.com/asset-\(i).jpg"],
                texts: [ContentItem(value: "Text \(i)")],
                ctas: nil
            )
        }
        
        // Wait for async storage
        let expectation = XCTestExpectation(description: "All definitions stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Verify a few random ones
        let definition0 = stateManager.getExperienceDefinition(for: "exp-0")
        let definition50 = stateManager.getExperienceDefinition(for: "exp-50")
        let definition99 = stateManager.getExperienceDefinition(for: "exp-99")
        
        XCTAssertNotNil(definition0)
        XCTAssertNotNil(definition50)
        XCTAssertNotNil(definition99)
        XCTAssertEqual(definition50?.assets.first, "https://example.com/asset-50.jpg")
    }
    
    // MARK: - Featurization Tracking Tests
    
    func testMarkExperienceDefinitionAsSent_FirstTime_MarksAsSent() {
        // Given
        let experienceId = "exp-sent"
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: ["https://example.com/asset.jpg"],
            texts: [ContentItem(value: "Text")],
            ctas: nil
        )
        
        // Wait for storage
        var expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        stateManager.markExperienceDefinitionAsSent(experienceId: experienceId)
        
        // Wait for update
        expectation = XCTestExpectation(description: "Marked as sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        let wasSent = stateManager.hasExperienceDefinitionBeenSent(for: experienceId)
        XCTAssertTrue(wasSent, "Should be marked as sent")
    }
    
    func testHasExperienceDefinitionBeenSent_SentExperience_ReturnsTrue() {
        // Given
        let experienceId = "exp-check-sent"
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: ["https://example.com/asset.jpg"],
            texts: [ContentItem(value: "Text")],
            ctas: nil
        )
        stateManager.markExperienceDefinitionAsSent(experienceId: experienceId)
        
        // Wait for operations
        let expectation = XCTestExpectation(description: "Operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let wasSent = stateManager.hasExperienceDefinitionBeenSent(for: experienceId)
        
        // Then
        XCTAssertTrue(wasSent)
    }
    
    func testHasExperienceDefinitionBeenSent_NewExperience_ReturnsFalse() {
        // Given
        let experienceId = "exp-not-sent"
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: ["https://example.com/asset.jpg"],
            texts: [ContentItem(value: "Text")],
            ctas: nil
        )
        
        // Wait for storage
        let expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let wasSent = stateManager.hasExperienceDefinitionBeenSent(for: experienceId)
        
        // Then
        XCTAssertFalse(wasSent, "New experience should not be marked as sent")
    }
    
    func testHasExperienceDefinitionBeenSent_NonExistentExperience_ReturnsFalse() {
        // When
        let wasSent = stateManager.hasExperienceDefinitionBeenSent(for: "non-existent")
        
        // Then
        XCTAssertFalse(wasSent, "Non-existent experience should return false")
    }
    
    func testMarkExperienceDefinitionAsSent_Deduplication_PreventsDuplicates() {
        // Given
        let experienceId = "exp-dedup"
        stateManager.storeExperienceDefinition(
            experienceId: experienceId,
            assets: ["https://example.com/asset.jpg"],
            texts: [ContentItem(value: "Text")],
            ctas: nil
        )
        
        // Wait for storage
        var expectation = XCTestExpectation(description: "Definition stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When - Mark as sent multiple times
        stateManager.markExperienceDefinitionAsSent(experienceId: experienceId)
        stateManager.markExperienceDefinitionAsSent(experienceId: experienceId)
        stateManager.markExperienceDefinitionAsSent(experienceId: experienceId)
        
        // Wait for updates
        expectation = XCTestExpectation(description: "All marks complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then - Should still be marked as sent (idempotent)
        let wasSent = stateManager.hasExperienceDefinitionBeenSent(for: experienceId)
        XCTAssertTrue(wasSent, "Should remain marked as sent (idempotent operation)")
    }
    
    // MARK: - URL Exclusion Tests
    
    func testShouldTrackUrl_NoConfiguration_ReturnsTrue() {
        // Given
        let url = URL(string: "https://example.com/page")!
        
        // When
        let shouldTrack = stateManager.shouldTrackUrl(url)
        
        // Then
        XCTAssertTrue(shouldTrack, "Should track when no configuration")
    }
    
    func testShouldTrackUrl_WithConfiguration_ReturnsCorrectValue() {
        // Given - Configuration with URL patterns (note: pattern compilation is tested in ConfigurationTests)
        // For StateManager tests, we just verify it delegates to configuration correctly
        let config = createTestConfiguration()
        stateManager.updateConfiguration(config)
        
        // Wait for config update
        let expectation = XCTestExpectation(description: "Config updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        let url = URL(string: "https://example.com/page.html")!
        
        // When
        let shouldTrack = stateManager.shouldTrackUrl(url)
        
        // Then - Should delegate to configuration (pattern matching tested in ConfigurationValidationTests)
        XCTAssertTrue(shouldTrack, "Should track URL when no exclusion patterns configured")
    }
    
    // MARK: - Experience Location Exclusion Tests
    
    func testShouldTrackExperience_NoConfiguration_ReturnsTrue() {
        // When
        let shouldTrack = stateManager.shouldTrackExperience(location: "home")
        
        // Then
        XCTAssertTrue(shouldTrack, "Should track when no configuration")
    }
    
    func testShouldTrackExperience_NilLocation_ReturnsTrue() {
        // Given
        let config = createTestConfiguration()
        stateManager.updateConfiguration(config)
        
        // Wait for config update
        let expectation = XCTestExpectation(description: "Config updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let shouldTrack = stateManager.shouldTrackExperience(location: nil)
        
        // Then
        XCTAssertTrue(shouldTrack, "Should track when location is nil")
    }
    
    func testShouldTrackExperience_WithConfiguration_ReturnsCorrectValue() {
        // Given - Configuration (note: pattern matching is tested in ConfigurationValidationTests)
        // For StateManager tests, we just verify it delegates to configuration correctly
        let config = createTestConfiguration()
        stateManager.updateConfiguration(config)
        
        // Wait for config update
        let expectation = XCTestExpectation(description: "Config updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        let shouldTrack = stateManager.shouldTrackExperience(location: "home")
        
        // Then - Should delegate to configuration
        XCTAssertTrue(shouldTrack, "Should track location when no exclusion patterns configured")
    }
    
    // MARK: - State Reset Tests
    
    func testReset_ClearsAllData() {
        // Given - Setup state with config and experiences
        let config = createTestConfiguration()
        stateManager.updateConfiguration(config)
        
        stateManager.storeExperienceDefinition(
            experienceId: "exp-1",
            assets: ["https://example.com/asset.jpg"],
            texts: [ContentItem(value: "Text")],
            ctas: nil
        )
        
        // Wait for setup
        var expectation = XCTestExpectation(description: "Setup complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Verify data exists
        XCTAssertNotNil(stateManager.getCurrentConfiguration())
        XCTAssertNotNil(stateManager.getExperienceDefinition(for: "exp-1"))
        
        // When
        stateManager.reset()
        
        // Wait for reset
        expectation = XCTestExpectation(description: "Reset complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then
        XCTAssertNil(stateManager.getCurrentConfiguration(), "Configuration should be cleared")
        XCTAssertNil(stateManager.getExperienceDefinition(for: "exp-1"), "Experience definitions should be cleared")
        XCTAssertFalse(stateManager.batchingEnabled, "Batching should be disabled after reset")
    }
    
    func testReset_MultipleExperiences_ClearsAll() {
        // Given - Store multiple experiences
        for i in 0..<10 {
            stateManager.storeExperienceDefinition(
                experienceId: "exp-\(i)",
                assets: ["https://example.com/asset-\(i).jpg"],
                texts: [ContentItem(value: "Text \(i)")],
                ctas: nil
            )
        }
        
        // Wait for storage
        var expectation = XCTestExpectation(description: "All stored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // When
        stateManager.reset()
        
        // Wait for reset
        expectation = XCTestExpectation(description: "Reset complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Then - Verify all cleared
        for i in 0..<10 {
            XCTAssertNil(stateManager.getExperienceDefinition(for: "exp-\(i)"), "Experience \(i) should be cleared")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess_ConfigurationUpdates_ThreadSafe() {
        // Given
        let iterations = 50
        let expectation = XCTestExpectation(description: "All concurrent operations complete")
        expectation.expectedFulfillmentCount = iterations
        
        // When - Concurrent config updates from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let config = self.createTestConfiguration(
                    batchingEnabled: i % 2 == 0
                )
                self.stateManager.updateConfiguration(config)
                expectation.fulfill()
            }
        }
        
        // Then - Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
        
        // Verify final state is valid
        let finalConfig = stateManager.getCurrentConfiguration()
        XCTAssertNotNil(finalConfig, "Should have a valid configuration after concurrent updates")
    }
    
    func testConcurrentAccess_ExperienceDefinitionStorage_ThreadSafe() {
        // Given
        let iterations = 50
        let expectation = XCTestExpectation(description: "All concurrent operations complete")
        expectation.expectedFulfillmentCount = iterations
        
        // When - Concurrent experience storage from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                self.stateManager.storeExperienceDefinition(
                    experienceId: "exp-\(i)",
                    assets: ["https://example.com/asset-\(i).jpg"],
                    texts: [ContentItem(value: "Text \(i)")],
                    ctas: nil
                )
                expectation.fulfill()
            }
        }
        
        // Then - Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
        
        // Wait for all async operations to complete
        let finalExpectation = XCTestExpectation(description: "Final state settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            finalExpectation.fulfill()
        }
        wait(for: [finalExpectation], timeout: 1.0)
        
        // Verify some random experiences were stored correctly
        XCTAssertNotNil(stateManager.getExperienceDefinition(for: "exp-0"))
        XCTAssertNotNil(stateManager.getExperienceDefinition(for: "exp-25"))
        XCTAssertNotNil(stateManager.getExperienceDefinition(for: "exp-49"))
    }
    
    func testConcurrentAccess_MixedOperations_ThreadSafe() {
        // Given
        let iterations = 100
        let expectation = XCTestExpectation(description: "All mixed operations complete")
        expectation.expectedFulfillmentCount = iterations
        
        // When - Mix of reads, writes, and resets from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                switch i % 4 {
                case 0:
                    // Store experience
                    self.stateManager.storeExperienceDefinition(
                        experienceId: "exp-\(i)",
                        assets: ["https://example.com/asset.jpg"],
                        texts: [ContentItem(value: "Text")],
                        ctas: nil
                    )
                case 1:
                    // Read experience
                    _ = self.stateManager.getExperienceDefinition(for: "exp-\(i - 1)")
                case 2:
                    // Update config
                    let config = self.createTestConfiguration()
                    self.stateManager.updateConfiguration(config)
                case 3:
                    // Read config
                    _ = self.stateManager.getCurrentConfiguration()
                default:
                    break
                }
                expectation.fulfill()
            }
        }
        
        // Then - Should complete without crashes or data corruption
        wait(for: [expectation], timeout: 10.0)
        // Success: concurrent mixed operations completed without crash
    }
}

