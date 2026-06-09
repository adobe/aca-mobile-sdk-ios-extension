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

@testable import AEPContentAnalytics
import XCTest

class ConfigurationManagerTests: XCTestCase {
    
    var configManager: ConfigurationManager!
    
    override func setUp() {
        super.setUp()
        configManager = ConfigurationManager()
    }
    
    override func tearDown() {
        configManager = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Update Tests
    
    func testUpdateConfiguration_Success() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = 50
        
        // When
        configManager.updateConfiguration(config)
        
        // Then
        let retrieved = configManager.getCurrentConfiguration()
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(retrieved?.batchingEnabled == true)
        XCTAssertEqual(retrieved?.maxBatchSize, 50)
    }
    
    func testBatchingEnabled_WhenConfigurationSet() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        
        // When
        configManager.updateConfiguration(config)
        
        // Then
        XCTAssertTrue(configManager.batchingEnabled)
    }
    
    func testBatchingEnabled_WhenNoConfiguration() {
        // Given - no configuration set
        
        // Then
        XCTAssertFalse(configManager.batchingEnabled)
    }
    
    // MARK: - URL Tracking Tests
    
    func testShouldTrackUrl_NoConfiguration_ReturnsTrue() {
        // Given
        let url = URL(string: "https://example.com")!
        
        // When/Then
        XCTAssertTrue(configManager.shouldTrackUrl(url))
    }
    
    func testShouldTrackUrl_WithExcludedPattern_ReturnsFalse() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = ".*internal.*"
        config.compileRegexPatterns()
        configManager.updateConfiguration(config)
        
        let url = URL(string: "https://example.com/internal/page")!
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackUrl(url))
    }
    
    func testShouldTrackUrl_WithNonMatchingPattern_ReturnsTrue() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = ".*internal.*"
        config.compileRegexPatterns()
        configManager.updateConfiguration(config)
        
        let url = URL(string: "https://example.com/public/page")!
        
        // When/Then
        XCTAssertTrue(configManager.shouldTrackUrl(url))
    }
    
    // MARK: - Experience Tracking Tests
    
    func testShouldTrackExperience_NoConfiguration_ReturnsTrue() {
        // When/Then
        XCTAssertTrue(configManager.shouldTrackExperience(location: "home"))
    }
    
    func testShouldTrackExperience_NilLocation_ReturnsTrue() {
        // When/Then
        XCTAssertTrue(configManager.shouldTrackExperience(location: nil))
    }
    
    func testShouldTrackExperience_WithExcludedLocation_ReturnsFalse() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.excludedExperienceLocationsRegexp = "admin.*"
        config.compileRegexPatterns()
        configManager.updateConfiguration(config)
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackExperience(location: "admin.settings"))
    }
    
    func testShouldTrackExperience_WithNonMatchingLocation_ReturnsTrue() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.excludedExperienceLocationsRegexp = "admin.*"
        config.compileRegexPatterns()
        configManager.updateConfiguration(config)
        
        // When/Then
        XCTAssertTrue(configManager.shouldTrackExperience(location: "home"))
    }
    
    // MARK: - Asset Location Tracking Tests
    
    func testShouldTrackAssetLocation_NoConfiguration_ReturnsTrue() {
        // When/Then
        XCTAssertTrue(configManager.shouldTrackAssetLocation("https://cdn.example.com/image.jpg"))
    }
    
    func testShouldTrackAssetLocation_NilLocation_ReturnsTrue() {
        // When/Then
        XCTAssertTrue(configManager.shouldTrackAssetLocation(nil))
    }
    
    func testShouldTrackAssetLocation_WithExcludedPattern_ReturnsFalse() {
        // Given
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetLocationsRegexp = ".*internal.*"
        config.compileRegexPatterns()
        configManager.updateConfiguration(config)
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackAssetLocation("https://cdn.example.com/internal/image.jpg"))
    }
    
    // MARK: - Reset Tests
    
    func testReset_RestoresDefaultConfiguration() {
        // Given - non-default configuration
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = 50
        config.experienceCloudOrgId = "TEST@AdobeOrg"
        configManager.updateConfiguration(config)
        XCTAssertEqual(configManager.getCurrentConfiguration()?.maxBatchSize, 50)

        // When
        configManager.reset()

        // Then - configuration is restored to defaults (not nil) so tracking remains operational
        // until a new Configuration shared state arrives.
        let resetConfig = configManager.getCurrentConfiguration()
        XCTAssertNotNil(resetConfig, "Configuration should be restored to defaults, not cleared")
        XCTAssertEqual(resetConfig?.maxBatchSize, ContentAnalyticsConfiguration().maxBatchSize)
        XCTAssertNil(resetConfig?.experienceCloudOrgId)
        XCTAssertTrue(configManager.batchingEnabled, "Default config has batching enabled")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess_ThreadSafe() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        
        // When - concurrent reads and writes
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            if index % 2 == 0 {
                self.configManager.updateConfiguration(config)
            } else {
                _ = self.configManager.getCurrentConfiguration()
                _ = self.configManager.batchingEnabled
            }
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // If we reach here without crashes, thread safety is working
    }
}
