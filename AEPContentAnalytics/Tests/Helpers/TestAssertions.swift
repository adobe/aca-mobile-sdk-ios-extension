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
@testable import AEPContentAnalytics

/// Reusable assertion helpers for common test scenarios
/// Reduces code duplication and provides consistent validation across tests
enum TestAssertions {
    
    // MARK: - Event Dispatch Assertions
    
    /// Asserts that an Edge event was dispatched
    /// - Parameters:
    ///   - events: Array of dispatched events to search
    ///   - expectedCount: Expected number of Edge events (default: at least 1)
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertEdgeEventDispatched(
        from events: [Event],
        expectedCount: Int? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let edgeEvents = events.filter { $0.type == EventType.edge }
        
        if let expectedCount = expectedCount {
            XCTAssertEqual(
                edgeEvents.count,
                expectedCount,
                "Expected \(expectedCount) Edge event(s), got \(edgeEvents.count)",
                file: file,
                line: line
            )
        } else {
            XCTAssertGreaterThan(
                edgeEvents.count,
                0,
                "Expected at least 1 Edge event, got none",
                file: file,
                line: line
            )
        }
    }
    
    /// Asserts that no Edge events were dispatched
    /// - Parameters:
    ///   - events: Array of dispatched events to search
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertNoEdgeEventsDispatched(
        from events: [Event],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let edgeEvents = events.filter { $0.type == EventType.edge }
        XCTAssertEqual(
            edgeEvents.count,
            0,
            "Expected no Edge events, but got \(edgeEvents.count)",
            file: file,
            line: line
        )
    }
    
    // MARK: - XDM Payload Assertions
    
    /// Asserts that an XDM payload is valid for a given entity type
    /// - Parameters:
    ///   - payload: XDM payload dictionary
    ///   - entityType: Expected entity type ("asset" or "experience")
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertXDMPayloadValid(
        _ payload: [String: Any],
        entityType: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Check required fields
        XCTAssertNotNil(payload["xdm"], "XDM payload should have 'xdm' field", file: file, line: line)
        
        guard let xdm = payload["xdm"] as? [String: Any] else {
            XCTFail("XDM payload 'xdm' field should be a dictionary", file: file, line: line)
            return
        }
        
        XCTAssertNotNil(xdm["eventType"], "XDM should have 'eventType'", file: file, line: line)
        XCTAssertNotNil(xdm["timestamp"], "XDM should have 'timestamp'", file: file, line: line)
        
        // Check entity-specific fields
        if entityType == ContentAnalyticsConstants.EntityType.asset {
            assertAssetXDMPayloadValid(xdm, file: file, line: line)
        } else if entityType == ContentAnalyticsConstants.EntityType.experience {
            assertExperienceXDMPayloadValid(xdm, file: file, line: line)
        }
    }
    
    /// Asserts that an asset XDM payload is valid
    private static func assertAssetXDMPayloadValid(
        _ xdm: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Asset-specific validation
        guard let contentAnalytics = xdm["_adobeinternal"] as? [String: Any],
              let contentComponent = contentAnalytics["contentComponent"] as? [String: Any] else {
            XCTFail("Asset XDM should have contentComponent structure", file: file, line: line)
            return
        }
        
        XCTAssertNotNil(
            contentComponent["assetURL"],
            "Asset XDM should have assetURL",
            file: file,
            line: line
        )
    }
    
    /// Asserts that an experience XDM payload is valid
    private static func assertExperienceXDMPayloadValid(
        _ xdm: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Experience-specific validation
        guard let contentAnalytics = xdm["_adobeinternal"] as? [String: Any],
              let experienceComponent = contentAnalytics["experienceComponent"] as? [String: Any] else {
            XCTFail("Experience XDM should have experienceComponent structure", file: file, line: line)
            return
        }
        
        XCTAssertNotNil(
            experienceComponent["experienceId"],
            "Experience XDM should have experienceId",
            file: file,
            line: line
        )
    }
    
    // MARK: - Metrics Assertions
    
    /// Asserts that metrics were calculated correctly from events
    /// - Parameters:
    ///   - metrics: Calculated metrics
    ///   - expectedViews: Expected view count
    ///   - expectedClicks: Expected click count
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertMetricsEqual(
        _ metrics: InteractionMetrics,
        expectedViews: Double,
        expectedClicks: Double,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            metrics.viewCount,
            expectedViews,
            "View count should be \(expectedViews), got \(metrics.viewCount)",
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            metrics.clickCount,
            expectedClicks,
            "Click count should be \(expectedClicks), got \(metrics.clickCount)",
            file: file,
            line: line
        )
    }
    
    /// Asserts that event array has expected interaction counts
    /// - Parameters:
    ///   - events: Array of events
    ///   - expectedViews: Expected view count
    ///   - expectedClicks: Expected click count
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertEventCounts(
        _ events: [Event],
        expectedViews: Int,
        expectedClicks: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            events.viewCount,
            expectedViews,
            "Expected \(expectedViews) view events, got \(events.viewCount)",
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            events.clickCount,
            expectedClicks,
            "Expected \(expectedClicks) click events, got \(events.clickCount)",
            file: file,
            line: line
        )
    }
    
    // MARK: - String Validation Assertions
    
    /// Asserts that a string is not empty
    /// - Parameters:
    ///   - value: String to validate
    ///   - description: Description for failure message
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertNotEmpty(
        _ value: String?,
        _ description: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(value, "\(description) should not be nil", file: file, line: line)
        XCTAssertFalse(
            value?.isEmpty ?? true,
            "\(description) should not be empty",
            file: file,
            line: line
        )
    }
    
    /// Asserts that a dictionary contains expected keys
    /// - Parameters:
    ///   - dictionary: Dictionary to validate
    ///   - expectedKeys: Array of expected keys
    ///   - file: Source file (auto-populated)
    ///   - line: Source line (auto-populated)
    static func assertContainsKeys(
        _ dictionary: [String: Any],
        expectedKeys: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for key in expectedKeys {
            XCTAssertNotNil(
                dictionary[key],
                "Dictionary should contain key '\(key)'",
                file: file,
                line: line
            )
        }
    }
}

