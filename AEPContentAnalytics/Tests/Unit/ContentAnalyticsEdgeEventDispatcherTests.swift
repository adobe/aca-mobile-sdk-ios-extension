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

/// Tests for edge event dispatcher: event dispatch, payload preservation, and thread safety.
class ContentAnalyticsEdgeEventDispatcherTests: XCTestCase {
    
    var dispatcher: EdgeEventDispatcher!
    var mockRuntime: TestableExtensionRuntime!
    
    override func setUp() {
        super.setUp()
        mockRuntime = TestableExtensionRuntime()
        dispatcher = EdgeEventDispatcher(runtime: mockRuntime)
    }
    
    override func tearDown() {
        dispatcher = nil
        mockRuntime = nil
        super.tearDown()
    }
    
    
    // MARK: - Basic Dispatch Tests
    
    func testDispatch_SingleEvent_DispatchesToRuntime() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 1, "Should dispatch exactly one event")
        XCTAssertEqual(mockRuntime.dispatchedEvents.first?.id, event.id, "Should dispatch the same event")
    }
    
    func testDispatch_MultipleEvents_DispatchesAll() {
        // Given
        let event1 = TestEventFactory.createEdgeAssetEvent(url: "https://example.com/asset1.jpg")
        let event2 = TestEventFactory.createEdgeAssetEvent(url: "https://example.com/asset2.jpg")
        let event3 = TestEventFactory.createEdgeExperienceEvent(id: "exp-1")
        
        // When
        dispatcher.dispatch(event: event1)
        dispatcher.dispatch(event: event2)
        dispatcher.dispatch(event: event3)
        
        // Then
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 3, "Should dispatch all three events")
        XCTAssertEqual(mockRuntime.dispatchedEvents[0].id, event1.id)
        XCTAssertEqual(mockRuntime.dispatchedEvents[1].id, event2.id)
        XCTAssertEqual(mockRuntime.dispatchedEvents[2].id, event3.id)
    }
    
    func testDispatch_SameEventMultipleTimes_DispatchesEachTime() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        
        // When
        dispatcher.dispatch(event: event)
        dispatcher.dispatch(event: event)
        dispatcher.dispatch(event: event)
        
        // Then
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 3, "Should dispatch the event three times")
        // All should have the same ID since it's the same event
        XCTAssertTrue(mockRuntime.dispatchedEvents.allSatisfy { $0.id == event.id })
    }
    
    // MARK: - Event Name Tests
    
    func testDispatch_AssetEvent_PreservesEventName() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        let expectedName = ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertEqual(dispatchedEvent?.name, expectedName, "Should preserve asset event name")
    }
    
    func testDispatch_ExperienceEvent_PreservesEventName() {
        // Given
        let event = TestEventFactory.createEdgeExperienceEvent()
        let expectedName = ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_EXPERIENCE
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertEqual(dispatchedEvent?.name, expectedName, "Should preserve experience event name")
    }
    
    // MARK: - Event Type Tests
    
    func testDispatch_Event_PreservesEventType() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        let expectedType = EventType.edge
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertEqual(dispatchedEvent?.type, expectedType, "Should preserve XDM content engagement type")
    }
    
    func testDispatch_Event_PreservesEventSource() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        let expectedSource = EventSource.requestContent
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertEqual(dispatchedEvent?.source, expectedSource, "Should preserve event source")
    }
    
    // MARK: - XDM Payload Tests
    
    func testDispatch_AssetEvent_PreservesXDMPayload() {
        // Given
        let assetURL = "https://example.com/test-asset.jpg"
        let event = TestEventFactory.createEdgeAssetEvent(url: assetURL)
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        let xdm = dispatchedEvent?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let assetID = assets?.first?["assetID"] as? String
        
        XCTAssertNotNil(xdm, "Should have XDM data")
        XCTAssertNotNil(experienceContent, "Should have experienceContent")
        XCTAssertNotNil(assets, "Should have assets array")
        XCTAssertEqual(assetID, assetURL, "Should preserve asset URL as assetID in XDM payload")
    }
    
    func testDispatch_ExperienceEvent_PreservesXDMPayload() {
        // Given
        let experienceId = "exp-test-123"
        let event = TestEventFactory.createEdgeExperienceEvent(id: experienceId)
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        let xdm = dispatchedEvent?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceID = experience?["experienceID"] as? String
        
        XCTAssertNotNil(xdm, "Should have XDM data")
        XCTAssertNotNil(experienceContent, "Should have experienceContent")
        XCTAssertNotNil(experience, "Should have experience data")
        XCTAssertEqual(experienceID, experienceId, "Should preserve experienceID in XDM payload")
    }
    
    func testDispatch_Event_PreservesEventType_InXDM() {
        // Given
        let event = TestEventFactory.createEdgeAssetEvent()
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        let xdm = dispatchedEvent?.data?["xdm"] as? [String: Any]
        let eventType = xdm?["eventType"] as? String
        
        XCTAssertNotNil(eventType, "Should have eventType in XDM")
        XCTAssertEqual(eventType, ContentAnalyticsConstants.EventType.xdmContentEngagement, 
                      "Should have correct XDM eventType")
    }
    
    // MARK: - Event Data Preservation Tests
    
    func testDispatch_EventWithComplexData_PreservesAllData() {
        // Given
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: [
                "xdm": [
                    "eventType": ContentAnalyticsConstants.EventType.xdmContentEngagement,
                    "experienceContent": [
                        "assets": [
                            [
                                "assetID": "https://example.com/asset.jpg",
                                "assetViews": ["value": 5],
                                "assetClicks": ["value": 2],
                                "assetExtras": [
                                    "width": 1920,
                                    "height": 1080,
                                    "format": "jpg"
                                ]
                            ]
                        ]
                    ]
                ],
                "customData": [
                    "key1": "value1",
                    "key2": 42
                ]
            ]
        )
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertNotNil(dispatchedEvent, "Should dispatch event")
        
        // Verify XDM data
        let xdm = dispatchedEvent?.data?["xdm"] as? [String: Any]
        XCTAssertNotNil(xdm, "Should preserve XDM data")
        
        // Verify custom data
        let customData = dispatchedEvent?.data?["customData"] as? [String: Any]
        XCTAssertNotNil(customData, "Should preserve custom data")
        XCTAssertEqual(customData?["key1"] as? String, "value1")
        XCTAssertEqual(customData?["key2"] as? Int, 42)
    }
    
    func testDispatch_EventWithEmptyData_HandlesGracefully() {
        // Given
        let event = Event(
            name: ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET,
            type: EventType.edge,
            source: EventSource.requestContent,
            data: [:]
        )
        
        // When
        dispatcher.dispatch(event: event)
        
        // Then
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 1, "Should dispatch event even with empty data")
        let dispatchedEvent = mockRuntime.dispatchedEvents.first
        XCTAssertNotNil(dispatchedEvent, "Should dispatch event")
        XCTAssertTrue(dispatchedEvent?.data?.isEmpty ?? true, "Should preserve empty data")
    }
    
    // MARK: - Thread Safety Tests
    
    func testDispatch_ConcurrentDispatches_ThreadSafe() {
        // Given
        let iterations = 50
        let expectation = XCTestExpectation(description: "All concurrent dispatches complete")
        expectation.expectedFulfillmentCount = iterations
        
        // When - Dispatch events concurrently from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let event = TestEventFactory.createEdgeAssetEvent(url: "https://example.com/asset\(i).jpg")
                self.dispatcher.dispatch(event: event)
                expectation.fulfill()
            }
        }
        
        // Then - Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all events were dispatched
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, iterations, 
                      "Should dispatch all \(iterations) events")
        // Success: concurrent dispatches handled without crash
    }
    
    // MARK: - Edge Case Tests
    
    func testDispatch_AfterMultipleDispatches_MaintainsOrder() {
        // Given
        let events = (0..<10).map { i in
            TestEventFactory.createEdgeAssetEvent(url: "https://example.com/asset\(i).jpg")
        }
        
        // When
        events.forEach { dispatcher.dispatch(event: $0) }
        
        // Then - Events should be dispatched in order
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 10, "Should dispatch all events")
        for (index, event) in events.enumerated() {
            XCTAssertEqual(mockRuntime.dispatchedEvents[index].id, event.id,
                          "Event \(index) should maintain order")
        }
    }
    
    func testDispatcher_Initialization_CreatesValidInstance() {
        // When
        let newDispatcher = EdgeEventDispatcher(runtime: mockRuntime)
        
        // Then
        XCTAssertNotNil(newDispatcher, "Should create valid dispatcher instance")
        
        // Verify it works
        let event = TestEventFactory.createEdgeAssetEvent()
        newDispatcher.dispatch(event: event)
        XCTAssertEqual(mockRuntime.dispatchedEvents.count, 1, "New dispatcher should work correctly")
    }
}

