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
import AEPCore
import AEPServices
@testable import AEPContentAnalytics

/// Tests for URL and Experience Location exclusion patterns
/// REFACTORED: Now uses ContentAnalyticsTestBase
class ContentAnalyticsExclusionTests: ContentAnalyticsTestBase {
    // ✅ mockRuntime and contentAnalytics available from base class
    
    var configuration: ContentAnalyticsConfiguration!
    
    override func setUp() {
        super.setUp() // Call base class setup
        configuration = ContentAnalyticsConfiguration()
    }
    
    override func tearDown() {
        configuration = nil
        super.tearDown()
    }
    
    // MARK: - URL Pattern Exclusion Tests
    
    func testExcludeUrl_ExactMatch_Excludes() {
        // Given - Exact URL pattern
        configuration.excludedAssetUrlsRegexp = "https://example\\.com/test\\.jpg"
        configuration.compileRegexPatterns()
        
        // When - Check exact match
        let url = URL(string: "https://example.com/test.jpg")!
        let shouldExclude = configuration.shouldExcludeUrl(url)
        
        // Then - Should exclude
        XCTAssertTrue(shouldExclude, "Exact URL match should be excluded")
    }
    
    func testExcludeUrl_ExactMatch_DoesNotExcludeOther() {
        // Given - Exact URL pattern
        configuration.excludedAssetUrlsRegexp = "https://example\\.com/test\\.jpg"
        configuration.compileRegexPatterns()
        
        // When - Check different URL
        let url = URL(string: "https://example.com/other.jpg")!
        let shouldExclude = configuration.shouldExcludeUrl(url)
        
        // Then - Should not exclude
        XCTAssertFalse(shouldExclude, "Different URL should not be excluded")
    }
    
    func testExcludeUrl_WildcardPattern_Excludes() {
        // Given - Wildcard pattern for all URLs containing "test"
        configuration.excludedAssetUrlsRegexp = ".*test.*"
        configuration.compileRegexPatterns()
        
        // When - Check test URLs
        let testUrls = [
            "https://images.test.example.com/hero.jpg",
            "https://cdn.test.com/banner.png",
            "https://test.example.com/image.jpg"
        ]
        
        // Then - All should be excluded
        for urlString in testUrls {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url), "\(urlString) should be excluded")
        }
    }
    
    func testExcludeUrl_LocalhostPattern_Excludes() {
        // Given - Localhost pattern
        configuration.excludedAssetUrlsRegexp = ".*localhost.*|.*127\\.0\\.0\\.1.*"
        configuration.compileRegexPatterns()
        
        // When - Check localhost URLs
        let localhostUrls = [
            "http://localhost:3000/image.jpg",
            "http://127.0.0.1:8080/test.png",
            "http://localhost/assets/hero.jpg"
        ]
        
        // Then - All should be excluded
        for urlString in localhostUrls {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url), "\(urlString) should be excluded")
        }
    }
    
    func testExcludeUrl_DevEnvironmentPattern_Excludes() {
        // Given - Dev environment pattern
        configuration.excludedAssetUrlsRegexp = ".*\\.dev\\..*|.*-dev\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check dev URLs
        let devUrls = [
            "https://cdn.dev.example.com/image.jpg",
            "https://images-dev.example.com/hero.png",
            "https://assets.dev.company.com/banner.jpg"
        ]
        
        // Then - All should be excluded
        for urlString in devUrls {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url), "\(urlString) should be excluded")
        }
    }
    
    func testExcludeUrl_MultiplePatterns_Excludes() {
        // Given - Multiple exclusion patterns combined
        configuration.excludedAssetUrlsRegexp = ".*\\.test\\..*|.*localhost.*|.*\\.dev\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check various URLs
        let excludedUrls = [
            "https://images.test.com/hero.jpg",     // matches .test.
            "http://localhost:3000/image.png",      // matches localhost
            "https://cdn.dev.example.com/hero.jpg"  // matches .dev.
        ]
        
        // Then - All should be excluded
        for urlString in excludedUrls {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url), "\(urlString) should be excluded")
        }
    }
    
    func testExcludeUrl_ProductionUrl_NotExcluded() {
        // Given - Dev/test patterns
        configuration.excludedAssetUrlsRegexp = ".*\\.test\\..*|.*\\.dev\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check production URLs
        let productionUrls = [
            "https://cdn.example.com/hero.jpg",
            "https://images.example.com/banner.png",
            "https://assets.company.com/product.jpg"
        ]
        
        // Then - None should be excluded
        for urlString in productionUrls {
            let url = URL(string: urlString)!
            XCTAssertFalse(configuration.shouldExcludeUrl(url), "\(urlString) should NOT be excluded")
        }
    }
    
    func testExcludeUrl_CaseInsensitive_Excludes() {
        // Given - Pattern
        configuration.excludedAssetUrlsRegexp = ".*TEST.*"
        configuration.compileRegexPatterns()
        
        // When - Check various cases
        let urls = [
            "https://example.com/TEST/image.jpg",
            "https://example.com/test/image.jpg",
            "https://example.com/Test/image.jpg"
        ]
        
        // Then - All should be excluded (case insensitive)
        for urlString in urls {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url), "\(urlString) should be excluded (case insensitive)")
        }
    }
    
    func testExcludeUrl_EmptyPatterns_ExcludesNothing() {
        // Given - Empty patterns
        configuration.excludedAssetUrlsRegexp = nil
        configuration.compileRegexPatterns()
        
        // When - Check any URL
        let url = URL(string: "https://example.com/test.jpg")!
        let shouldExclude = configuration.shouldExcludeUrl(url)
        
        // Then - Should not exclude
        XCTAssertFalse(shouldExclude, "Empty patterns should exclude nothing")
    }
    
    func testExcludeUrl_InvalidPattern_HandlesGracefully() {
        // Given - Invalid regex pattern (unmatched bracket)
        configuration.excludedAssetUrlsRegexp = "[invalid(regex"
        configuration.compileRegexPatterns()
        
        // When - Check URL
        let url = URL(string: "https://example.com/test.jpg")!
        let shouldExclude = configuration.shouldExcludeUrl(url)
        
        // Then - Should not exclude (invalid pattern ignored)
        XCTAssertFalse(shouldExclude, "Invalid pattern should be ignored")
        XCTAssertNil(configuration.compiledAssetUrlRegex, "Invalid pattern should not compile")
    }
    
    // MARK: - Experience Location Exclusion Tests
    
    func testExcludeExperience_ExactLocationMatch_Excludes() {
        // Given - Exact location using regex
        configuration.excludedExperienceLocationsRegexp = "^test\\.hero$"
        configuration.compileRegexPatterns()
        
        // When - Check exact match
        let shouldExclude = configuration.shouldExcludeExperience(location: "test.hero")
        
        // Then - Should exclude
        XCTAssertTrue(shouldExclude, "Exact location match should be excluded")
    }
    
    func testExcludeExperience_RegexPattern_Excludes() {
        // Given - Regex pattern for test experiences
        configuration.excludedExperienceLocationsRegexp = "^test\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check test locations
        let testLocations = [
            "test.hero",
            "test.product.detail",
            "test.checkout.cart"
        ]
        
        // Then - All should be excluded
        for location in testLocations {
            XCTAssertTrue(configuration.shouldExcludeExperience(location: location), 
                         "\(location) should be excluded")
        }
    }
    
    func testExcludeExperience_RegexPattern_DoesNotExcludeOther() {
        // Given - Regex pattern for test experiences
        configuration.excludedExperienceLocationsRegexp = "^test\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check production locations
        let productionLocations = [
            "home.hero",
            "product.detail",
            "checkout.cart"
        ]
        
        // Then - None should be excluded
        for location in productionLocations {
            XCTAssertFalse(configuration.shouldExcludeExperience(location: location), 
                          "\(location) should NOT be excluded")
        }
    }
    
    func testExcludeExperience_WildcardPattern_Excludes() {
        // Given - Wildcard pattern for internal experiences
        configuration.excludedExperienceLocationsRegexp = ".*\\.internal$"
        configuration.compileRegexPatterns()
        
        // When - Check internal locations
        let internalLocations = [
            "admin.dashboard.internal",
            "test.page.internal",
            "debug.view.internal"
        ]
        
        // Then - All should be excluded
        for location in internalLocations {
            XCTAssertTrue(configuration.shouldExcludeExperience(location: location), 
                         "\(location) should be excluded")
        }
    }
    
    func testExcludeExperience_MultiplePatterns_Excludes() {
        // Given - Multiple exclusion patterns
        configuration.excludedExperienceLocationsRegexp = "^test\\..*|^dev\\..*|.*\\.internal$"
        configuration.compileRegexPatterns()
        
        // When - Check various locations
        let excludedLocations = [
            "test.hero",
            "dev.product.detail",
            "admin.dashboard.internal"
        ]
        
        // Then - All should be excluded
        for location in excludedLocations {
            XCTAssertTrue(configuration.shouldExcludeExperience(location: location), 
                         "\(location) should be excluded")
        }
    }
    
    func testExcludeExperience_CombinedPatterns_Excludes() {
        // Given - Multiple patterns combined (exact + wildcard)
        configuration.excludedExperienceLocationsRegexp = "^admin\\.dashboard$|^test\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check both types
        XCTAssertTrue(configuration.shouldExcludeExperience(location: "admin.dashboard"), 
                     "Exact pattern match should be excluded")
        XCTAssertTrue(configuration.shouldExcludeExperience(location: "test.hero"), 
                     "Wildcard pattern match should be excluded")
        XCTAssertFalse(configuration.shouldExcludeExperience(location: "home.hero"), 
                      "Non-matching location should not be excluded")
    }
    
    func testExcludeExperience_CaseInsensitive_Excludes() {
        // Given - Pattern
        configuration.excludedExperienceLocationsRegexp = "^TEST\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check various cases
        let locations = [
            "TEST.hero",
            "test.hero",
            "Test.hero"
        ]
        
        // Then - All should be excluded (case insensitive)
        for location in locations {
            XCTAssertTrue(configuration.shouldExcludeExperience(location: location), 
                         "\(location) should be excluded (case insensitive)")
        }
    }
    
    func testExcludeExperience_EmptyPatterns_ExcludesNothing() {
        // Given - Empty patterns
        configuration.excludedExperienceLocationsRegexp = nil
        configuration.compileRegexPatterns()
        
        // When - Check any location
        let shouldExclude = configuration.shouldExcludeExperience(location: "home.hero")
        
        // Then - Should not exclude
        XCTAssertFalse(shouldExclude, "Empty patterns should exclude nothing")
    }
    
    func testExcludeExperience_InvalidPattern_HandlesGracefully() {
        // Given - Invalid regex pattern
        configuration.excludedExperienceLocationsRegexp = "[invalid(regex"
        configuration.compileRegexPatterns()
        
        // When - Check location
        let shouldExclude = configuration.shouldExcludeExperience(location: "home.hero")
        
        // Then - Should not exclude (invalid pattern ignored)
        XCTAssertFalse(shouldExclude, "Invalid pattern should be ignored")
        XCTAssertNil(configuration.compiledExperienceLocationRegex, 
                      "Invalid pattern should not compile")
    }
    
    // MARK: - Integration Tests with ContentAnalytics Extension
    
    func testNonExcludedAsset_DispatchedToEdge() {
        // Given - Configuration with excluded URL pattern
        let config: [String: Any] = [
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.test\\..*",
            "contentanalytics.batchingEnabled": false  // Disable batching for immediate dispatch
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        ))
        waitForAsync(timeout: 0.3)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        let initialEventCount = mockRuntime.dispatchedEvents.count
        
        // When - Track asset with production URL (NOT excluded)
        let trackEvent = TestEventFactory.createAssetEvent(
            url: "https://cdn.example.com/hero.jpg",
            location: "home",
            interaction: .view
        )
        
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.3)
        
        // Then - Non-excluded asset should be dispatched
        let finalEventCount = mockRuntime.dispatchedEvents.count
        XCTAssertGreaterThan(finalEventCount, initialEventCount,
                            "Non-excluded asset should be dispatched to Edge")
    }
    
    func testExcludedExperience_NeverDispatchedToEdge() {
        // Given - Configuration with excluded experience pattern
        let config: [String: Any] = [
            "contentanalytics.excludedExperienceLocationsRegexp": "^test\\..*"
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        ))
        waitForAsync(timeout: 0.3)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // When - Track experience with excluded location
        let trackEvent = TestEventFactory.createExperienceEvent(
            id: "exp_test_123",
            location: "test.hero",
            interaction: .view
        )
        
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.3)
        
        // Then - No events should be dispatched to Edge
        let edgeEvents = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        XCTAssertEqual(edgeEvents.count, 0, 
                      "Excluded experience should not dispatch Edge events")
    }
    
    func testExclusionPattern_UpdateDynamically() {
        // Given - Initial configuration with no exclusions
        let initialConfig: [String: Any] = [
            "contentanalytics.excludedAssetUrlsRegexp": ""
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: initialConfig
        ))
        waitForAsync(timeout: 0.2)
        
        // When - Update configuration to add exclusions
        let updatedConfig: [String: Any] = [
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.test\\..*"
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: updatedConfig
        ))
        waitForAsync(timeout: 0.2)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // Then - Exclusion should be active
        let trackEvent = TestEventFactory.createAssetEvent(
            url: "https://images.test.example.com/hero.jpg",
            location: "home",
            interaction: .view
        )
        
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.3)
        
        // Verify no Edge events dispatched
        let edgeEvents = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        XCTAssertEqual(edgeEvents.count, 0, 
                      "Updated exclusion pattern should be active")
    }
    
    func testExclusionPattern_MidSession_AppliesToNewEventsOnly() {
        // Given - Initial configuration with no exclusions
        let initialConfig: [String: Any] = [
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.excludedAssetUrlsRegexp": ""
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: initialConfig
        ))
        waitForAsync(timeout: 0.2)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // When - Track asset BEFORE exclusion is added
        let testURL = "https://cdn.example.com/test-image.jpg"
        let trackEvent = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "assetURL": testURL,
                "assetLocation": "home",
                "interactionType": "view"
            ]
        )
        
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.2)
        
        // Then - Asset should be tracked (no exclusions yet)
        let eventsBeforeExclusion = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        XCTAssertGreaterThan(eventsBeforeExclusion.count, 0,
                            "Asset should be tracked before exclusion pattern is added")
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // When - Add exclusion pattern for test-* URLs
        let updatedConfig: [String: Any] = [
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.excludedAssetUrlsRegexp": "^https://cdn\\.example\\.com/test-.*"
        ]
        
        mockRuntime.simulateSharedState(
            for: ("com.adobe.module.configuration", 
                  Event(name: "Config", type: EventType.configuration, source: EventSource.responseContent, data: updatedConfig)),
            data: (value: updatedConfig, status: .set)
        )
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: updatedConfig
        ))
        waitForAsync(timeout: 0.2)
        
        // When - Track SAME asset AFTER exclusion is added
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.2)
        
        // Then - Asset should now be EXCLUDED (no new events)
        let eventsAfterExclusion = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        XCTAssertEqual(eventsAfterExclusion.count, 0,
                      "Same asset should be excluded after exclusion pattern is added")
    }
    
    func testExcludedAsset_NeverDispatchedToEdge() {
        // Given - Configuration with excluded URL pattern
        let config: [String: Any] = [
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.test\\..*"
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        ))
        waitForAsync(timeout: 0.3)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // When - Track asset with excluded URL
        let trackEvent = TestEventFactory.createAssetEvent(
            url: "https://cdn.test.example.com/hero.jpg",
            location: "home",
            interaction: .view
        )
        
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.3)
        
        // Then - No Edge events should be dispatched
        let edgeEvents = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        XCTAssertEqual(edgeEvents.count, 0,
                      "Excluded asset should not dispatch to Edge")
    }
    
    func testMixedAssets_OnlyNonExcludedDispatched() {
        // Given - Pattern excludes test URLs
        let config: [String: Any] = [
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.test\\..*"
        ]
        
        mockRuntime.simulateComingEvents(Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        ))
        waitForAsync(timeout: 0.3)
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        
        // When - Track BOTH excluded and non-excluded assets
        let excludedAsset = TestEventFactory.createAssetEvent(
            url: "https://cdn.test.example.com/hero.jpg",
            location: "home",
            interaction: .view
        )
        let includedAsset = TestEventFactory.createAssetEvent(
            url: "https://cdn.example.com/hero.jpg",
            location: "home",
            interaction: .view
        )
        
        mockRuntime.simulateComingEvents(excludedAsset)
        waitForAsync(timeout: 0.2)
        
        let eventsAfterExcluded = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        
        mockRuntime.simulateComingEvents(includedAsset)
        waitForAsync(timeout: 0.2)
        
        // Then - Only non-excluded asset dispatched
        let allEdgeEvents = mockRuntime.dispatchedEvents.filter { 
            $0.type == "com.adobe.eventType.edge" 
        }
        
        XCTAssertEqual(eventsAfterExcluded.count, 0,
                      "Excluded asset should not dispatch")
        XCTAssertGreaterThan(allEdgeEvents.count, eventsAfterExcluded.count,
                            "Non-excluded asset should dispatch")
    }
    
    func testExcludeUrl_WithQueryParams_HandlesCorrectly() {
        // Given - Pattern for base URL
        configuration.excludedAssetUrlsRegexp = "^https://cdn\\.test\\.example\\.com/.*"
        configuration.compileRegexPatterns()
        
        // When - Check URLs with query parameters
        let urlsWithParams = [
            "https://cdn.test.example.com/hero.jpg?v=123",
            "https://cdn.test.example.com/hero.jpg?width=500&height=300",
            "https://cdn.test.example.com/assets/banner.png?cache=false"
        ]
        
        // Then - Should match base URL and exclude
        for urlString in urlsWithParams {
            let url = URL(string: urlString)!
            XCTAssertTrue(configuration.shouldExcludeUrl(url),
                         "\(urlString) should be excluded despite query params")
        }
    }
    
    // MARK: - Performance Tests
    
    func testExclusionPattern_Performance_1000URLs() {
        // Given - Multiple patterns combined
        configuration.excludedAssetUrlsRegexp = ".*\\.test\\..*|.*localhost.*|.*\\.dev\\..*|.*-staging\\..*"
        configuration.compileRegexPatterns()
        
        // When - Check 1000 URLs
        let startTime = Date()
        
        for i in 0..<1000 {
            let url = URL(string: "https://cdn.example.com/image\(i).jpg")!
            _ = configuration.shouldExcludeUrl(url)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Then - Should complete quickly (< 1s for 1000 checks in debug build)
        XCTAssertLessThan(duration, 1.0, "1000 URL checks should complete in < 1 second")
    }
    
    func testExclusionPattern_Performance_ComplexRegex() {
        // Given - Complex regex pattern
        configuration.excludedAssetUrlsRegexp = "^https?://(?:www\\.)?(?:test|dev|staging)\\.example\\.com/.*$"
        configuration.compileRegexPatterns()
        
        // When - Check URLs
        let startTime = Date()
        
        for i in 0..<1000 {
            let url = URL(string: "https://cdn.example.com/image\(i).jpg")!
            _ = configuration.shouldExcludeUrl(url)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Then - Should still be reasonably fast
        // Note: Increased tolerance to account for CI/system load variability
        XCTAssertLessThan(duration, 0.5, "Complex regex should still be performant (< 500ms for 1000 checks)")
    }
}

