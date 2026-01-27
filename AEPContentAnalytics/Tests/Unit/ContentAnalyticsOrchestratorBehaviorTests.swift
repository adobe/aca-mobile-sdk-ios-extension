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
import AEPCore
import AEPServices
import XCTest

/// Tests for orchestrator event validation and lifecycle.
/// Configuration changes tested in ContentAnalyticsOrchestratorConfigurationTests.
final class ContentAnalyticsOrchestratorBehaviorTests: ContentAnalyticsOrchestratorTestBase {

    // MARK: - Asset Event Validation Tests

    func testAssetEvent_MissingAssetURL_RejectedWithError() {
        // Given - Asset event without REQUIRED assetURL
        let invalidEvent = TestEventFactory.createAssetEventMissingURL()

        // When - Process invalid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(invalidEvent) { result in
            // Then - Should fail with validation error
            if case .failure(let error) = result {
                let errorMessage = error.localizedDescription
                XCTAssertTrue(
                    errorMessage.contains("required") ||
                    errorMessage.contains("Missing") ||
                    errorMessage.contains("assetURL"),
                    "Should indicate missing required field: \(errorMessage)"
                )
            } else {
                XCTFail("Should fail validation for missing assetURL")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify no events dispatched
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0, "Invalid event should not be dispatched")
    }

    func testAssetEvent_MissingInteractionType_RejectedWithError() {
        // Given - Asset event without REQUIRED interactionType
        let invalidEvent = TestEventFactory.createAssetEventMissingInteractionType()

        // When - Process invalid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(invalidEvent) { result in
            // Then - Should fail
            if case .failure = result {
                // Success - validation caught it
            } else {
                XCTFail("Should fail validation for missing interactionType")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify no dispatch
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0)
    }

    func testAssetEvent_WithoutOptionalLocation_StillValid() {
        // Given - Valid asset event WITHOUT optional assetLocation
        let validEvent = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                AssetTrackingEventPayload.RequiredFields.assetURL: "https://example.com/image.jpg",
                AssetTrackingEventPayload.RequiredFields.interactionType: "view"
                // No assetLocation - but that's OK, it's optional!
            ]
        )

        // When - Process valid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(validEvent) { result in
            // Then - Should succeed (location is optional!)
            if case .success = result {
                // Success
            } else {
                XCTFail("Event without optional assetLocation should still be valid")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify event was dispatched
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 1, "Valid event should be dispatched")
    }

    func testAssetEvent_WithAllFields_Accepted() {
        // Given - Valid asset event with all fields (required + optional)
        let validEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        // When - Process valid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(validEvent) { result in
            // Then - Should succeed
            if case .success = result {
                // Success
            } else {
                XCTFail("Valid event should be accepted")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify event was dispatched
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 1, "Valid event should be dispatched")
    }

    func testAssetEvent_EmptyData_RejectedGracefully() {
        // Given - Event with empty data
        let emptyEvent = TestEventFactory.createAssetEventWithEmptyData()

        // When - Process empty event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(emptyEvent) { result in
            // Then - Should fail gracefully (not crash)
            if case .failure = result {
                // Expected - validation should catch missing fields
            } else {
                XCTFail("Empty event should be rejected")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify no dispatch
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0)
    }

    func testAssetEvent_NilData_RejectedGracefully() {
        // Given - Event with nil data
        let nilEvent = TestEventFactory.createAssetEventWithNilData()

        // When - Process nil event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(nilEvent) { result in
            // Then - Should fail gracefully (not crash)
            if case .failure = result {
                // Expected
            } else {
                XCTFail("Nil data event should be rejected")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Should not crash, should not dispatch
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0)
    }

    // MARK: - Experience Event Validation Tests

    func testExperienceEvent_MissingExperienceId_RejectedWithError() {
        // Given - Experience event without REQUIRED experienceId
        let invalidEvent = TestEventFactory.createExperienceEventMissingId()

        // When - Process invalid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processExperienceEvent(invalidEvent) { result in
            // Then - Should fail
            if case .failure = result {
                // Expected
            } else {
                XCTFail("Should fail validation for missing experienceId")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify no dispatch
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0)
    }

    func testExperienceEvent_MissingInteractionType_RejectedWithError() {
        // Given - Experience event without REQUIRED interactionType
        let invalidEvent = TestEventFactory.createExperienceEventMissingInteractionType()

        // When - Process invalid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processExperienceEvent(invalidEvent) { result in
            // Then - Should fail
            if case .failure = result {
                // Expected
            } else {
                XCTFail("Should fail validation for missing interactionType")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify no dispatch
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 0)
    }

    func testExperienceEvent_WithoutOptionalLocation_StillValid() {
        // Given - Valid experience event WITHOUT optional experienceLocation
        let validEvent = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                ExperienceTrackingEventPayload.RequiredFields.experienceId: "exp-123",
                ExperienceTrackingEventPayload.RequiredFields.interactionType: "view"
                // No experienceLocation - but that's OK, it's optional!
            ]
        )

        // When - Process valid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processExperienceEvent(validEvent) { result in
            // Then - Should succeed (location is optional!)
            if case .success = result {
                // Success
            } else {
                XCTFail("Event without optional experienceLocation should still be valid")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Should dispatch at least interaction event
        XCTAssertGreaterThan(mockEventDispatcher.dispatchedEvents.count, 0, "Valid event should be dispatched")
    }

    func testExperienceEvent_WithAllFields_Accepted() {
        // Given - Valid experience event with all fields
        let validEvent = TestEventFactory.createExperienceEvent(
            id: "exp-123",
            location: "detail",
            interaction: .view
        )

        // When - Process valid event
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processExperienceEvent(validEvent) { result in
            // Then - Should succeed
            if case .success = result {
                // Success
            } else {
                XCTFail("Valid experience event should be accepted")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Should dispatch definition + interaction (or just interaction if already registered)
        XCTAssertGreaterThan(mockEventDispatcher.dispatchedEvents.count, 0, "Valid event should be dispatched")
    }

    // MARK: - Experience Definition Lifecycle Tests

    func testExperienceDefinition_SentOnce_NotRepeatedOnSubsequentInteractions() {
        // Given - First interaction with an experience
        let event1 = TestEventFactory.createExperienceEvent(
            id: "exp-once",
            location: "detail",
            interaction: .view
        )

        // When - Process first interaction
        let expectation1 = self.expectation(description: "First interaction")
        orchestrator.processExperienceEvent(event1) { _ in
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let initialDispatchCount = mockEventDispatcher.dispatchedEvents.count

        // Should have dispatched definition + interaction
        XCTAssertGreaterThanOrEqual(initialDispatchCount, 1, "Should dispatch at least interaction event")

        // Reset dispatcher to track only second interaction
        mockEventDispatcher.dispatchedEvents.removeAll()

        // When - Second interaction with same experience
        let event2 = TestEventFactory.createExperienceEvent(
            id: "exp-once",
            location: "detail",
            interaction: .click
        )

        let expectation2 = self.expectation(description: "Second interaction")
        orchestrator.processExperienceEvent(event2) { _ in
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then - Should only send interaction event, not definition again
        let secondDispatchCount = mockEventDispatcher.dispatchedEvents.count

        // Second interaction should dispatch fewer or equal events (no duplicate definition)
        XCTAssertLessThanOrEqual(
            secondDispatchCount,
            initialDispatchCount,
            "Subsequent interactions should not re-send definition"
        )
    }

    // MARK: - Edge Case Tests

    // NOTE: Privacy validation tests removed - ContentAnalytics follows "Send to Edge, Let Edge Filter" 
    // architecture where Edge extension handles privacy validation, not ContentAnalytics.
    // See ContentAnalyticsPrivacyTests.swift for privacy testing.

    func testUnknownInteractionType_HandledGracefully() {
        // Given - Event with unknown interaction type (as string)
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: [
                AssetTrackingEventPayload.RequiredFields.assetURL: "https://example.com/image.jpg",
                AssetTrackingEventPayload.RequiredFields.interactionType: "unknown_type" // Invalid type
            ]
        )

        // When - Process event with unknown type
        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(event) { _ in
            // Then - Should handle gracefully (either accept or reject, but not crash)
            // Both behaviors are valid: accept with unknown type OR reject as invalid
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Should not crash - main success criterion
        // Dispatch behavior is implementation-dependent
    }

    func testMultipleEventsInQuickSuccession_AllProcessed() {
        // Given - Multiple valid events
        let events = (1...5).map { i in
            TestEventFactory.createAssetEvent(
                url: "https://example.com/image\(i).jpg",
                location: "gallery",
                interaction: .view
            )
        }

        // When - Process all events quickly
        let expectation = self.expectation(description: "All events processed")
        expectation.expectedFulfillmentCount = 5

        for event in events {
            orchestrator.processAssetEvent(event) { result in
                if case .success = result {
                    expectation.fulfill()
                } else {
                    XCTFail("Valid events should be accepted")
                }
            }
        }

        waitForExpectations(timeout: 2.0)

        // Then - All events should be dispatched
        XCTAssertEqual(mockEventDispatcher.dispatchedEvents.count, 5, "All valid events should be dispatched")
    }
}
