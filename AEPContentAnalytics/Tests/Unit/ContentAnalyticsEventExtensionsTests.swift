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

/// Tests for Event extensions: type detection, data accessors, key generation, and array helpers.
class ContentAnalyticsEventExtensionsTests: XCTestCase {
    
    // MARK: - Event Type Detection Tests
    
    func testIsAssetEvent_WithAssetEvent_ReturnsTrue() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertTrue(event.isAssetEvent, "Should identify asset event correctly")
    }
    
    func testIsAssetEvent_WithExperienceEvent_ReturnsFalse() {
        // Given
        let event = TestEventFactory.createExperienceEvent(
            id: "exp-123",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertFalse(event.isAssetEvent, "Should not identify experience event as asset event")
    }
    
    func testIsExperienceEvent_WithExperienceEvent_ReturnsTrue() {
        // Given
        let event = TestEventFactory.createExperienceEvent(
            id: "exp-123",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertTrue(event.isExperienceEvent, "Should identify experience event correctly")
    }
    
    func testIsExperienceEvent_WithAssetEvent_ReturnsFalse() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertFalse(event.isExperienceEvent, "Should not identify asset event as experience event")
    }
    
    // MARK: - Asset Data Accessor Tests
    
    func testAssetURL_WithValidEvent_ExtractsCorrectly() {
        // Given
        let url = "https://example.com/image.jpg"
        let event = TestEventFactory.createAssetEvent(
            url: url,
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertEqual(event.assetURL, url, "Should extract asset URL correctly")
    }
    
    func testAssetURL_WithMissingField_ReturnsNil() {
        // Given
        let event = Event(
            name: "Test",
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: ["other": "data"]
        )
        
        // When/Then
        XCTAssertNil(event.assetURL, "Should return nil when assetURL is missing")
    }
    
    func testAssetLocation_WithValidEvent_ExtractsCorrectly() {
        // Given
        let location = "homepage"
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: location,
            interaction: .view
        )
        
        // When/Then
        XCTAssertEqual(event.assetLocation, location, "Should extract asset location correctly")
    }
    
    func testAssetExtras_WithValidEvent_ExtractsCorrectly() {
        // Given
        let extras = ["campaign": "summer2024"]
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view,
            extras: extras
        )
        
        // When/Then
        XCTAssertNotNil(event.assetExtras, "Should extract asset extras")
        XCTAssertEqual(event.assetExtras?["campaign"] as? String, "summer2024")
    }
    
    // MARK: - Experience Data Accessor Tests
    
    func testExperienceId_WithValidEvent_ExtractsCorrectly() {
        // Given
        let experienceId = "mobile-abc123"
        let event = TestEventFactory.createExperienceEvent(
            id: experienceId,
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertEqual(event.experienceId, experienceId, "Should extract experience ID correctly")
    }
    
    func testExperienceLocation_WithValidEvent_ExtractsCorrectly() {
        // Given
        let location = "product-detail"
        let event = TestEventFactory.createExperienceEvent(
            id: "exp-123",
            location: location,
            interaction: .view
        )
        
        // When/Then
        XCTAssertEqual(event.experienceLocation, location, "Should extract experience location correctly")
    }
    
    func testExperienceExtras_WithValidEvent_ExtractsCorrectly() {
        // Given
        let extras = ["variant": "A"]
        let event = TestEventFactory.createExperienceEvent(
            id: "exp-123",
            location: "home",
            interaction: .view,
            extras: extras
        )
        
        // When/Then
        XCTAssertNotNil(event.experienceExtras, "Should extract experience extras")
        XCTAssertEqual(event.experienceExtras?["variant"] as? String, "A")
    }
    
    // MARK: - Interaction Type Tests
    
    func testInteractionType_ViewEvent_ReturnsView() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertEqual(event.interactionType, .view, "Should extract view interaction type")
    }
    
    func testInteractionType_ClickEvent_ReturnsClick() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .click
        )
        
        // When/Then
        XCTAssertEqual(event.interactionType, .click, "Should extract click interaction type")
    }
    
    func testIsView_WithViewEvent_ReturnsTrue() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )
        
        // When/Then
        XCTAssertTrue(event.isView, "Should identify view event")
    }
    
    func testIsClick_WithClickEvent_ReturnsTrue() {
        // Given
        let event = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .click
        )
        
        // When/Then
        XCTAssertTrue(event.isClick, "Should identify click event")
    }
    
    // MARK: - Key Generation Tests
    
    func testAssetKey_WithValidEvent_GeneratesCorrectly() {
        // Given
        let url = "https://example.com/image.jpg"
        let location = "home"
        let event = TestEventFactory.createAssetEvent(
            url: url,
            location: location,
            interaction: .view
        )
        
        // When
        let key = event.assetKey
        
        // Then
        XCTAssertNotNil(key, "Should generate asset key")
        XCTAssertEqual(key, "https://example.com/image.jpg?location=home")
    }
    
    func testAssetKey_WithoutLocation_GeneratesURLOnly() {
        // Given
        let url = "https://example.com/image.jpg"
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "assetURL": url,
                "interactionType": "view"
                // No assetLocation
            ]
        )
        
        // When
        let key = event.assetKey
        
        // Then
        XCTAssertEqual(key, url, "Should generate key from URL only when no location")
    }
    
    func testExperienceKey_WithValidEvent_GeneratesCorrectly() {
        // Given
        let experienceId = "mobile-abc123"
        let location = "home"
        let event = TestEventFactory.createExperienceEvent(
            id: experienceId,
            location: location,
            interaction: .view
        )
        
        // When
        let key = event.experienceKey
        
        // Then
        XCTAssertNotNil(key, "Should generate experience key")
        XCTAssertEqual(key, "mobile-abc123?location=home")
    }
    
    // MARK: - Array Extension Tests
    
    func testViewCount_WithMixedEvents_CountsCorrectly() {
        // Given
        let events = [
            TestEventFactory.createAssetEvent(url: "https://example.com/1.jpg", location: "home", interaction: .view),
            TestEventFactory.createAssetEvent(url: "https://example.com/2.jpg", location: "home", interaction: .view),
            TestEventFactory.createAssetEvent(url: "https://example.com/3.jpg", location: "home", interaction: .click)
        ]
        
        // When/Then
        XCTAssertEqual(events.viewCount, 2, "Should count 2 view events")
    }
    
    func testClickCount_WithMixedEvents_CountsCorrectly() {
        // Given
        let events = [
            TestEventFactory.createAssetEvent(url: "https://example.com/1.jpg", location: "home", interaction: .view),
            TestEventFactory.createAssetEvent(url: "https://example.com/2.jpg", location: "home", interaction: .click),
            TestEventFactory.createAssetEvent(url: "https://example.com/3.jpg", location: "home", interaction: .click)
        ]
        
        // When/Then
        XCTAssertEqual(events.clickCount, 2, "Should count 2 click events")
    }
    
    func testTriggeringInteractionType_WithViewFirst_ReturnsView() {
        // Given
        let events = [
            TestEventFactory.createAssetEvent(url: "https://example.com/1.jpg", location: "home", interaction: .view),
            TestEventFactory.createAssetEvent(url: "https://example.com/2.jpg", location: "home", interaction: .click)
        ]
        
        // When/Then
        XCTAssertEqual(events.triggeringInteractionType, .view, "Should return first event's interaction type")
    }
    
    func testTriggeringInteractionType_WithEmptyArray_ReturnsClick() {
        // Given
        let events: [Event] = []
        
        // When/Then
        XCTAssertEqual(events.triggeringInteractionType, .click, "Should default to click for empty array")
    }
    
    func testInteractions_FiltersOutDefinitions() {
        // Given
        let events = [
            TestEventFactory.createAssetEvent(url: "https://example.com/1.jpg", location: "home", interaction: .view),
            TestEventFactory.createAssetEvent(url: "https://example.com/2.jpg", location: "home", interaction: .click),
            // Add a definition event
            Event(
                name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
                type: ContentAnalyticsConstants.EventType.contentAnalytics,
                source: EventSource.requestContent,
                data: [
                    "experienceId": "exp-123",
                    "interactionType": "definition"
                ]
            )
        ]
        
        // When
        let interactions = events.interactions
        
        // Then
        XCTAssertEqual(interactions.count, 2, "Should filter out definition event")
        XCTAssertTrue(interactions.allSatisfy { !$0.isExperienceDefinition })
    }
}

