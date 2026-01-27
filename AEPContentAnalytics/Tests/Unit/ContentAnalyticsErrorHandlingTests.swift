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

/// Tests error handling for invalid event data.
/// Validates that events with missing/invalid required fields are dropped.
///
/// NOTE: Edge case data (Unicode, long strings, concurrency, high volume) will be tested
/// in integration tests where we can verify end-to-end behavior.
class ContentAnalyticsErrorHandlingTests: ContentAnalyticsOrchestratorTestBase {
    
    private func wait(timeout: TimeInterval = 0.2) {
        Thread.sleep(forTimeInterval: timeout)
    }
    
    // MARK: - Invalid Event Data (Unit Testable)
    
    func testMissingAssetURL_EventDropped() {
        // Given - Event without required assetURL
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "interactionType": "view",
                "assetLocation": "test"
            ]
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event without assetURL should be dropped")
    }
    
    func testMissingExperienceId_EventDropped() {
        // Given - Event without required experienceId
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "interactionType": "view",
                "experienceLocation": "test"
            ]
        )
        
        // When
        orchestrator.processExperienceEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.experienceEvents.count, 0, "Event without experienceId should be dropped")
    }
    
    func testMissingInteractionType_EventDropped() {
        // Given - Event without required interactionType
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "assetURL": "https://example.com/test.jpg",
                "assetLocation": "test"
            ]
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event without interactionType should be dropped")
    }
    
    func testInvalidInteractionType_EventDropped() {
        // Given - Event with invalid interactionType
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "assetURL": "https://example.com/test.jpg",
                "interactionType": "invalid_type"
            ]
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event with invalid interactionType should be dropped")
    }
    
    func testNilEventData_EventDropped() {
        // Given - Event with nil data
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: nil
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event with nil data should be dropped")
    }
    
    func testEmptyEventData_EventDropped() {
        // Given - Event with empty data
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [:]
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event with empty data should be dropped")
    }
    
    func testWrongTypeForURL_EventDropped() {
        // Given - Event with wrong type for assetURL
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                "assetURL": 12345,  // Wrong type
                "interactionType": "view"
            ]
        )
        
        // When
        orchestrator.processAssetEvent(event) { _ in }
        wait()
        
        // Then
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 0, "Event with wrong type for assetURL should be dropped")
    }
}
