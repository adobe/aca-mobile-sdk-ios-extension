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
import AEPCore
import XCTest

/// Tests for EventExclusionFilter - filters events based on URL and location patterns
final class EventExclusionFilterTests: XCTestCase {
    
    var stateManager: ContentAnalyticsStateManager!
    var filter: EventExclusionFilter!
    
    override func setUp() {
        super.setUp()
        stateManager = ContentAnalyticsStateManager()
        filter = EventExclusionFilter(state: stateManager)
        
        // Apply basic configuration
        var config = ContentAnalyticsConfiguration()
        config.trackExperiences = true
        stateManager.updateConfiguration(config)
        waitForConfiguration()
    }
    
    override func tearDown() {
        filter = nil
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Asset URL Exclusion Tests
    
    func testShouldExcludeAsset_withNoExclusionPatterns_returnsFalse() {
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetLocation: "header"
        )
        
        XCTAssertFalse(filter.shouldExcludeAsset(event), "Should not exclude when no patterns configured")
    }
    
    func testShouldExcludeAsset_withMatchingURLPattern_returnsTrue() {
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = ".*\\.gif$"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createAssetEvent(
            assetURL: "https://example.com/animation.gif",
            assetLocation: "content"
        )
        
        XCTAssertTrue(filter.shouldExcludeAsset(event), "Should exclude URLs matching pattern")
    }
    
    func testShouldExcludeAsset_withNonMatchingURLPattern_returnsFalse() {
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = ".*\\.gif$"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetLocation: "content"
        )
        
        XCTAssertFalse(filter.shouldExcludeAsset(event), "Should not exclude URLs not matching pattern")
    }
    
    // MARK: - Asset Location Exclusion Tests
    
    func testShouldExcludeAsset_withMatchingLocationPattern_returnsTrue() {
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetLocationsRegexp = "^footer.*"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetLocation: "footer-banner"
        )
        
        XCTAssertTrue(filter.shouldExcludeAsset(event), "Should exclude locations matching pattern")
    }
    
    func testShouldExcludeAsset_withNonMatchingLocationPattern_returnsFalse() {
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetLocationsRegexp = "^footer.*"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetLocation: "header-banner"
        )
        
        XCTAssertFalse(filter.shouldExcludeAsset(event), "Should not exclude locations not matching pattern")
    }
    
    // MARK: - Experience Location Exclusion Tests
    
    func testShouldExcludeExperience_withNoExclusionPatterns_returnsFalse() {
        let event = createExperienceEvent(
            experienceId: "exp-123",
            experienceLocation: "home-page"
        )
        
        XCTAssertFalse(filter.shouldExcludeExperience(event), "Should not exclude when no patterns configured")
    }
    
    func testShouldExcludeExperience_withMatchingLocationPattern_returnsTrue() {
        var config = ContentAnalyticsConfiguration()
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createExperienceEvent(
            experienceId: "exp-123",
            experienceLocation: "test-environment"
        )
        
        XCTAssertTrue(filter.shouldExcludeExperience(event), "Should exclude experiences matching pattern")
    }
    
    func testShouldExcludeExperience_withNonMatchingLocationPattern_returnsFalse() {
        var config = ContentAnalyticsConfiguration()
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createExperienceEvent(
            experienceId: "exp-123",
            experienceLocation: "production-page"
        )
        
        XCTAssertFalse(filter.shouldExcludeExperience(event), "Should not exclude experiences not matching pattern")
    }
    
    // MARK: - Edge Cases
    
    func testShouldExcludeAsset_withNilAssetURL_returnsFalse() {
        let event = createAssetEvent(
            assetURL: nil,
            assetLocation: "header"
        )
        
        // Should not exclude, let validation handle missing URL
        XCTAssertFalse(filter.shouldExcludeAsset(event), "Should not exclude when URL is nil")
    }
    
    func testShouldExcludeAsset_withNilLocation_returnsFalse() {
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetLocationsRegexp = "^footer.*"
        config.compileRegexPatterns()
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetLocation: nil
        )
        
        XCTAssertFalse(filter.shouldExcludeAsset(event), "Should not exclude when location is nil")
    }
    
    // MARK: - Helper Methods
    
    private func createAssetEvent(
        assetURL: String?,
        assetLocation: String?
    ) -> Event {
        var data: [String: Any] = [:]
        
        if let assetURL = assetURL {
            data["assetURL"] = assetURL
        }
        if let assetLocation = assetLocation {
            data["assetLocation"] = assetLocation
        }
        data["action"] = InteractionType.view.rawValue
        
        return Event(
            name: "Content Analytics Asset Event",
            type: EventType.genericTrack,
            source: EventSource.requestContent,
            data: data
        )
    }
    
    private func createExperienceEvent(
        experienceId: String?,
        experienceLocation: String?
    ) -> Event {
        var data: [String: Any] = [:]
        
        if let experienceId = experienceId {
            data["experienceId"] = experienceId
        }
        if let experienceLocation = experienceLocation {
            data["experienceLocation"] = experienceLocation
        }
        data["action"] = InteractionType.view.rawValue
        
        return Event(
            name: "Content Analytics Experience Event",
            type: EventType.genericTrack,
            source: EventSource.requestContent,
            data: data
        )
    }
    
    private func waitForConfiguration() {
        let startTime = Date()
        let timeout: TimeInterval = 1.0
        
        while stateManager.getCurrentConfiguration() == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
