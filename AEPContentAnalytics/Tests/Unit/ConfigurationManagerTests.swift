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
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 50,
            flushInterval: 10.0,
            maxWaitTime: 20.0,
            excludedUrlPatterns: [],
            excludedLocations: []
        )
        
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
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [],
            excludedLocations: []
        )
        
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
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [".*internal.*"],
            excludedLocations: []
        )
        configManager.updateConfiguration(config)
        
        let url = URL(string: "https://example.com/internal/page")!
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackUrl(url))
    }
    
    func testShouldTrackUrl_WithNonMatchingPattern_ReturnsTrue() {
        // Given
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [".*internal.*"],
            excludedLocations: []
        )
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
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [],
            excludedLocations: ["admin.*"]
        )
        configManager.updateConfiguration(config)
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackExperience(location: "admin.settings"))
    }
    
    func testShouldTrackExperience_WithNonMatchingLocation_ReturnsTrue() {
        // Given
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [],
            excludedLocations: ["admin.*"]
        )
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
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [".*internal.*"],
            excludedLocations: []
        )
        configManager.updateConfiguration(config)
        
        // When/Then
        XCTAssertFalse(configManager.shouldTrackAssetLocation("https://cdn.example.com/internal/image.jpg"))
    }
    
    // MARK: - Reset Tests
    
    func testReset_ClearsConfiguration() {
        // Given
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 50,
            flushInterval: 10.0,
            maxWaitTime: 20.0,
            excludedUrlPatterns: [],
            excludedLocations: []
        )
        configManager.updateConfiguration(config)
        XCTAssertNotNil(configManager.getCurrentConfiguration())
        
        // When
        configManager.reset()
        
        // Then
        XCTAssertNil(configManager.getCurrentConfiguration())
        XCTAssertFalse(configManager.batchingEnabled)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess_ThreadSafe() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        let config = ContentAnalyticsConfiguration(
            batchingEnabled: true,
            maxBatchSize: 10,
            flushInterval: 2.0,
            maxWaitTime: 5.0,
            excludedUrlPatterns: [],
            excludedLocations: []
        )
        
        // When - concurrent reads and writes
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            if index % 2 == 0 {
                configManager.updateConfiguration(config)
            } else {
                _ = configManager.getCurrentConfiguration()
                _ = configManager.batchingEnabled
            }
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // If we reach here without crashes, thread safety is working
    }
}
