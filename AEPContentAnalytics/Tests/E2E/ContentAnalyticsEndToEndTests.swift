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
import AEPTestUtils
import XCTest

/// End-to-end integration tests for ContentAnalytics event flow.
/// Tests complete flows from public API → extension → orchestrator → Edge events.
///
/// **Priority: HIGH** - These verify critical user-facing functionality
final class ContentAnalyticsEndToEndTests: XCTestCase {

    var mockRuntime: TestableExtensionRuntime!
    var contentAnalytics: ContentAnalytics!

    override func setUp() {
        super.setUp()

        // Create mock runtime
        mockRuntime = TestableExtensionRuntime()

        // Set Hub shared state (required for privacy validator)
        let hubData: [String: Any] = [
            ContentAnalyticsConstants.HubSharedState.EXTENSIONS_KEY: [:]  // Empty extensions = no Consent extension
        ]
        mockRuntime.simulateSharedState(
            for: ContentAnalyticsConstants.ExternalExtensions.EVENT_HUB,
            data: (value: hubData, status: .set)
        )

        // Set default configuration BEFORE registering extension
        let configData: [String: Any] = [
            "contentanalytics.trackExperiences": true,
            "contentanalytics.batchingEnabled": false
        ]

        // Set shared state (extension will read this on registration)
        mockRuntime.simulateSharedState(
            for: "com.adobe.module.configuration",
            data: (value: configData, status: .set)
        )

        // Register extension (will read config from shared state)
        contentAnalytics = ContentAnalytics(runtime: mockRuntime)
        contentAnalytics.onRegistered()

        // Also send configuration event
        let configEvent = Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: configData
        )

        // Set shared state for the event too
        mockRuntime.simulateSharedState(
            for: ("com.adobe.module.configuration", configEvent),
            data: (value: configData, status: .set)
        )

        // Dispatch configuration event
        mockRuntime.simulateComingEvents(configEvent)

        // Wait for configuration to be processed (async operation)
        Thread.sleep(forTimeInterval: 1.0)

        // Reset events after setup
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
    }

    override func tearDown() {
        contentAnalytics?.onUnregistered()
        contentAnalytics = nil
        mockRuntime = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func sendConfiguration(_ config: [String: Any]) {
        let configEvent = Event(
            name: "Configuration Response",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        )

        // Set shared state BEFORE dispatching event
        mockRuntime.simulateSharedState(
            for: "com.adobe.module.configuration",
            data: (value: config, status: .set)
        )

        // Also set for the specific event
        mockRuntime.simulateSharedState(
            for: ("com.adobe.module.configuration", configEvent),
            data: (value: config, status: .set)
        )

        // Dispatch event
        mockRuntime.simulateComingEvents(configEvent)

        // Wait for async processing chain using expectation
        let expectation = XCTestExpectation(description: "Configuration processed")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    private func trackAssetAndWait(url: String, interaction: InteractionType = .view, location: String? = nil, additionalData: [String: Any]? = nil) {
        // Create asset tracking event
        var eventData: [String: Any] = [
            AssetTrackingEventPayload.RequiredFields.assetURL: url,
            AssetTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue
        ]

        if let location = location {
            eventData[AssetTrackingEventPayload.OptionalFields.assetLocation] = location
        }

        if let additionalData = additionalData {
            eventData.merge(additionalData) { _, new in new }
        }

        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: eventData
        )

        // Simulate event coming to extension
        mockRuntime.simulateComingEvents(event)

        // Note: No sleep here - test will use waitForEdgeEvents() to wait for actual results
        // This allows batching to work naturally with async processing
    }

    private func registerExperienceAndWait(assets: [ContentItem], texts: [ContentItem], ctas: [ContentItem]?, location: String) -> String {
        let experienceId = ContentAnalyticsUtilities.generateExperienceId(
            from: assets,
            texts: texts,
            ctas: ctas
        )

        // Convert ContentItem objects to dictionaries for event data
        // NOTE: assetURLs expects [String] (just the URLs), not full ContentItem dictionaries
        let assetURLs = assets.map { $0.value }
        let textDicts = texts.map { $0.toDictionary() }

        var eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: InteractionType.definition.stringValue,
            ExperienceTrackingEventPayload.OptionalFields.assetURLs: assetURLs,
            ExperienceTrackingEventPayload.OptionalFields.texts: textDicts
        ]

        if let ctas = ctas {
            let ctaDicts = ctas.map { $0.toDictionary() }
            eventData[ExperienceTrackingEventPayload.OptionalFields.ctas] = ctaDicts
        }

        if !location.isEmpty {
            eventData[ExperienceTrackingEventPayload.OptionalFields.experienceLocation] = location
        }

        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: eventData
        )

        mockRuntime.simulateComingEvents(event)
        Thread.sleep(forTimeInterval: 0.3)

        return experienceId
    }

    private func trackExperienceAndWait(experienceId: String, interaction: InteractionType = .view, additionalData: [String: Any]? = nil) {
        var eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: interaction.stringValue
        ]

        if let additionalData = additionalData {
            eventData.merge(additionalData) { _, new in new }
        }

        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: eventData
        )

        mockRuntime.simulateComingEvents(event)
        // Note: No sleep here - test will use waitForEdgeEvents() to wait for actual results
    }

    private func waitForEdgeEvents(count: Int, timeout: TimeInterval = 5.0) -> [Event] {
        let expectation = XCTestExpectation(description: "Wait for \(count) Edge events")
        expectation.expectedFulfillmentCount = count

        // Monitor dispatched events
        let startCount = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }.count

        // Track how many times we've fulfilled the expectation
        var fulfilledCount = 0

        // Poll for edge events (mockRuntime doesn't have callbacks)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let edgeEvents = self.mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
            let newEvents = edgeEvents.count - startCount

            if newEvents > fulfilledCount {
                print("   Edge events: \(edgeEvents.count) (new: \(newEvents - fulfilledCount))")
            }

            // Fulfill only for events we haven't fulfilled yet (newEvents is cumulative)
            let toFulfill = min(newEvents, count) - fulfilledCount
            for _ in 0..<toFulfill {
                expectation.fulfill()
                fulfilledCount += 1
            }

            if fulfilledCount >= count {
                timer.invalidate()
            }
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()

        let edgeEvents = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }

        if result != .completed {
            print("   Timeout: Expected \(count) events, got \(edgeEvents.count - startCount)")
            print("   Total dispatched: \(mockRuntime.dispatchedEvents.count)")
            for (index, event) in mockRuntime.dispatchedEvents.enumerated() {
                print("     Event \(index + 1): \(event.name) (\(event.type))")
            }
        }

        return edgeEvents
    }

    // MARK: - Asset Tracking Flow

    func testAssetTracking_DispatachesEdgeEvent() {
        // Given - Extension is configured

        // When - Track asset
        trackAssetAndWait(url: "https://example.com/image.jpg", location: "home")

        // Then - Edge event should be dispatched
        let edgeEvents = waitForEdgeEvents(count: 1)

        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch exactly one Edge event")

        // Verify XDM structure
        let event = edgeEvents.first!
        let xdm = event.data?["xdm"] as? [String: Any]

        XCTAssertNotNil(xdm, "Edge event should have XDM data")
        XCTAssertEqual(xdm?["eventType"] as? String, "content.contentEngagement", "Should have correct eventType")

        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        XCTAssertNotNil(experienceContent, "Should have experienceContent")

        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assets, "Should have assets array")
        XCTAssertEqual(assets?.count, 1, "Should have 1 asset")

        let asset = assets?.first
        XCTAssertEqual(asset?["assetID"] as? String, "https://example.com/image.jpg", "Should preserve asset URL")
    }

    func testAssetTrackingWithExtras_IncludesExtrasInXDM() {
        // Given - Asset with extras
        let extras = ["category": "product", "price": 99.99] as [String: Any]

        // When - Track asset with extras (wrap in assetExtras key)
        trackAssetAndWait(
            url: "https://example.com/product.jpg",
            location: "catalog",
            additionalData: [AssetTrackingEventPayload.OptionalFields.assetExtras: extras]
        )

        // Then - Extras should be in XDM
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1)

        let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]
        let assetExtras = assets?.first?["assetExtras"] as? [String: Any]

        XCTAssertNotNil(assetExtras, "Should have assetExtras")
        XCTAssertEqual(assetExtras?["category"] as? String, "product")
        XCTAssertEqual(assetExtras?["price"] as? Double, 99.99)
    }

    // MARK: - Experience Tracking Flow

    func testExperienceTracking_DispatchesEdgeEvent() {
        // Given - Register experience first
        let experienceId = registerExperienceAndWait(
            assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
            texts: [ContentItem(value: "Welcome", styles: [:])],
            ctas: nil,
            location: "home"
        )

        // Reset events after registration
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track experience
        trackExperienceAndWait(experienceId: experienceId)

        // Then - Edge event should be dispatched
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch experience Edge event")

        // Verify XDM structure
        let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]

        XCTAssertNotNil(experience, "Should have experience data")
        XCTAssertEqual(experience?["experienceID"] as? String, experienceId, "Should have correct experience ID")
        XCTAssertEqual(experience?["experienceChannel"] as? String, "mobile", "Should have mobile channel")
    }

    // MARK: - Batching vs Non-Batching Payload Comparison

    // MARK: Location-Based Grouping Tests

    func testBatchingOn_SameAssetNoLocation_AggregatesMetrics() {
        // Given - Batching enabled
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset twice WITHOUT location
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: nil)
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: nil)

        Thread.sleep(forTimeInterval: 1.5)

        // Then - Should aggregate into 1 event with viewCount = 2
        let edgeEvents = waitForEdgeEvents(count: 1, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 1, "No location: Should aggregate into single event")

        let xdm = edgeEvents[0].data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 1, "Should have 1 aggregated asset")
        XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/product.jpg")

        // XDM uses nested structure: assetViews: {value: N}
        let assetViews = assets?[0]["assetViews"] as? [String: Any]
        // Metrics can be Double or Int from JSON
        let viewCountValue = assetViews?["value"] as? NSNumber
        XCTAssertEqual(viewCountValue?.intValue, 2, "Metrics aggregated: assetViews.value = 2")

        // XDM uses "assetSource" not "assetLocation"
        XCTAssertNil(assets?[0]["assetSource"], "No location should be set")
    }

    func testBatchingOn_SameAssetSameLocation_AggregatesMetrics() {
        // Given - Batching enabled
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset twice WITH SAME location
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")

        Thread.sleep(forTimeInterval: 1.5)

        // Then - Should aggregate into 1 event with viewCount = 2
        let edgeEvents = waitForEdgeEvents(count: 1, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 1, "Same location: Should aggregate into single event")

        let xdm = edgeEvents[0].data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 1, "Should have 1 aggregated asset")
        XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/product.jpg")

        // XDM uses nested structure: assetViews: {value: N}
        let assetViews = assets?[0]["assetViews"] as? [String: Any]
        // Metrics can be Double or Int from JSON
        let viewCountValue = assetViews?["value"] as? NSNumber
        XCTAssertEqual(viewCountValue?.intValue, 2, "Metrics aggregated: assetViews.value = 2")

        // XDM uses "assetSource" not "assetLocation"
        XCTAssertEqual(assets?[0]["assetSource"] as? String, "catalog", "Location preserved as assetSource in XDM")
    }

    func testBatchingOn_SameAssetDifferentLocations_SendsSeparateEvents() {
        // Given - Batching enabled with batch size = 2
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset twice WITH DIFFERENT locations
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "home")
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")

        Thread.sleep(forTimeInterval: 1.5)

        // Then - Location acts as grouping key → should send 2 separate events
        let edgeEvents = waitForEdgeEvents(count: 2, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 2, "Different locations: Should send separate events even in batching mode")

        // Extract locations from both events (order may vary due to dictionary iteration)
        var locations: [String] = []
        for event in edgeEvents {
            let xdm = event.data?["xdm"] as? [String: Any]
            let content = xdm?["experienceContent"] as? [String: Any]
            let assets = content?["assets"] as? [[String: Any]]

            XCTAssertEqual(assets?.count, 1, "Each event should have 1 asset")
            XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/product.jpg")

            if let location = assets?[0]["assetSource"] as? String {
                locations.append(location)
            }
        }

        // Verify both locations are present (regardless of order)
        XCTAssertTrue(locations.contains("home"), "Should have event with 'home' location")
        XCTAssertTrue(locations.contains("catalog"), "Should have event with 'catalog' location")
        XCTAssertEqual(Set(locations).count, 2, "Should have 2 distinct locations")
    }

    func testBatchingOff_SameAssetDifferentLocations_SendsSeparateEvents() {
        // Given - Batching disabled
        sendConfiguration([
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset with different locations
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "home")
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")

        // Then - Non-batching always sends separate events
        let edgeEvents = waitForEdgeEvents(count: 2)
        XCTAssertEqual(edgeEvents.count, 2, "Non-batching: Always sends separate events")

        // Verify locations are preserved (XDM uses "assetSource")
        let event1Xdm = edgeEvents[0].data?["xdm"] as? [String: Any]
        let event1Content = event1Xdm?["experienceContent"] as? [String: Any]
        let event1Assets = event1Content?["assets"] as? [[String: Any]]
        XCTAssertEqual(event1Assets?[0]["assetSource"] as? String, "home")

        let event2Xdm = edgeEvents[1].data?["xdm"] as? [String: Any]
        let event2Content = event2Xdm?["experienceContent"] as? [String: Any]
        let event2Assets = event2Content?["assets"] as? [[String: Any]]
        XCTAssertEqual(event2Assets?[0]["assetSource"] as? String, "catalog")
    }

    func testBatchingOff_MultipleInteractions_SendsSeparateEventsWithIndividualMetrics() {
        // Given - Batching disabled (default)
        sendConfiguration([
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset twice
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")

        // Then - Should send 2 separate Edge events with INDEPENDENT metrics
        let edgeEvents = waitForEdgeEvents(count: 2)
        XCTAssertEqual(edgeEvents.count, 2, "Non-batching: Should send 2 separate events")

        // Each event is independent with viewCount = 1 (no aggregation in non-batching mode)
        for (index, event) in edgeEvents.enumerated() {
            let xdm = event.data?["xdm"] as? [String: Any]
            let content = xdm?["experienceContent"] as? [String: Any]
            let assets = content?["assets"] as? [[String: Any]]

            XCTAssertEqual(assets?.count, 1, "Event \(index + 1) should have 1 asset")
            XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/product.jpg")

            // Each event has viewCount = 1 (independent, not cumulative)
            let assetViews = assets?[0]["assetViews"] as? [String: Any]
            let viewCount = assetViews?["value"] as? NSNumber
            XCTAssertEqual(viewCount?.intValue, 1, "Event \(index + 1) has independent viewCount = 1 (no batching)")
        }
    }

    func testBatchingOn_MultipleInteractions_SendsSingleEventWithAggregatedMetrics() {
        // Given - Batching enabled with batch size = 2
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same asset twice (reaches batch size)
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")
        trackAssetAndWait(url: "https://example.com/product.jpg", interaction: .view, location: "catalog")

        // Then - Should send 1 aggregated Edge event
        // waitForEdgeEvents polls for events with proper expectation tracking
        let edgeEvents = waitForEdgeEvents(count: 1, timeout: 10.0)
        XCTAssertGreaterThan(edgeEvents.count, 0, "Batching: Should send at least 1 aggregated event")

        // Verify aggregated payload
        let xdm = edgeEvents[0].data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        // Should have 1 asset with aggregated metrics
        XCTAssertEqual(assets?.count, 1, "Batched event should have 1 asset (same assetID)")
        XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/product.jpg")

        // XDM wraps metrics: assetViews: {value: N}
        let assetViews = assets?[0]["assetViews"] as? [String: Any]
        let viewCountValue = assetViews?["value"] as? NSNumber
        XCTAssertEqual(viewCountValue?.intValue, 2, "Batched event has aggregated viewCount")
    }

    func testBatchingComparison_DifferentAssets_PayloadStructureDiffers() {
        // Part 1: Non-batching - Multiple separate events
        sendConfiguration([
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        trackAssetAndWait(url: "https://example.com/image1.jpg", interaction: .view, location: "gallery")
        trackAssetAndWait(url: "https://example.com/image2.jpg", interaction: .view, location: "gallery")

        let nonBatchedEvents = waitForEdgeEvents(count: 2)
        XCTAssertEqual(nonBatchedEvents.count, 2, "Non-batching: 2 events for 2 different assets")

        // Each event has 1 asset
        for event in nonBatchedEvents {
            let xdm = event.data?["xdm"] as? [String: Any]
            let experienceContent = xdm?["experienceContent"] as? [String: Any]
            let assets = experienceContent?["assets"] as? [[String: Any]]
            XCTAssertEqual(assets?.count, 1, "Non-batched: Each event has 1 asset")
        }

        // Part 2: Batching - Different assets (even same location) send separate events
        // This enables proper CJA analysis: filter by assetID, segment by asset performance
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        trackAssetAndWait(url: "https://example.com/image3.jpg", interaction: .view, location: "gallery")
        trackAssetAndWait(url: "https://example.com/image4.jpg", interaction: .view, location: "gallery")

        // Even with batching, different assets send separate events for proper CJA breakdown
        // waitForEdgeEvents polls for events with proper expectation tracking  
        let batchedEvents = waitForEdgeEvents(count: 2, timeout: 10.0)
        XCTAssertEqual(batchedEvents.count, 2, "Batching: 2 events for 2 different assets (enables CJA asset-level analysis)")

        // Each event has 1 asset (proper for CJA filtering/segmentation)
        for event in batchedEvents {
            let xdm = event.data?["xdm"] as? [String: Any]
            let experienceContent = xdm?["experienceContent"] as? [String: Any]
            let assets = experienceContent?["assets"] as? [[String: Any]]
            XCTAssertEqual(assets?.count, 1, "Batched: Each event has 1 asset for proper CJA breakdown")
        }
    }

    // MARK: Experience Location-Based Grouping Tests

    func testBatchingOn_SameExperienceDifferentLocations_SendsSeparateEvents() {
        // Given - Batching enabled
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])

        // Register experience
        let experienceId = registerExperienceAndWait(
            assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
            texts: [ContentItem(value: "Welcome", styles: [:])],
            ctas: nil,
            location: "home"
        )

        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same experience with DIFFERENT locations
        trackExperienceAndWait(experienceId: experienceId, interaction: .view, additionalData: [
            ExperienceTrackingEventPayload.OptionalFields.experienceLocation: "home"
        ])
        trackExperienceAndWait(experienceId: experienceId, interaction: .view, additionalData: [
            ExperienceTrackingEventPayload.OptionalFields.experienceLocation: "catalog"
        ])

        Thread.sleep(forTimeInterval: 1.5)

        // Then - Different locations → separate events
        let edgeEvents = waitForEdgeEvents(count: 2, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 2, "Different experience locations: Should send separate events")

        // Extract locations from both events (order may vary due to dictionary iteration)
        var locations: [String] = []
        for event in edgeEvents {
            let xdm = event.data?["xdm"] as? [String: Any]
            let content = xdm?["experienceContent"] as? [String: Any]
            let experience = content?["experience"] as? [String: Any]

            XCTAssertEqual(experience?["experienceID"] as? String, experienceId, "Each event has correct experienceID")

            if let location = experience?["experienceSource"] as? String {
                locations.append(location)
            }
        }

        // Verify both locations are present (regardless of order)
        XCTAssertTrue(locations.contains("home"), "Should have event with 'home' location")
        XCTAssertTrue(locations.contains("catalog"), "Should have event with 'catalog' location")
        XCTAssertEqual(Set(locations).count, 2, "Should have 2 distinct locations")
    }

    func testBatchingOn_SameExperienceSameLocation_AggregatesMetrics() {
        // Given - Batching enabled
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])

        // Register experience
        let experienceId = registerExperienceAndWait(
            assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
            texts: [ContentItem(value: "Welcome", styles: [:])],
            ctas: nil,
            location: "home"
        )

        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track same experience with SAME location twice
        trackExperienceAndWait(experienceId: experienceId, interaction: .view, additionalData: [
            ExperienceTrackingEventPayload.OptionalFields.experienceLocation: "home"
        ])
        trackExperienceAndWait(experienceId: experienceId, interaction: .view, additionalData: [
            ExperienceTrackingEventPayload.OptionalFields.experienceLocation: "home"
        ])

        Thread.sleep(forTimeInterval: 1.5)

        // Then - Same location → aggregated metrics
        let edgeEvents = waitForEdgeEvents(count: 1, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 1, "Same experience location: Should aggregate into single event")

        let xdm = edgeEvents[0].data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]

        XCTAssertEqual(experience?["experienceID"] as? String, experienceId)
        // XDM uses "experienceSource" not "experienceLocation"
        XCTAssertEqual(experience?["experienceSource"] as? String, "home")

        // XDM wraps metrics: experienceViews: {value: N}
        let experienceViews = experience?["experienceViews"] as? [String: Any]
        let viewCountValue = experienceViews?["value"] as? NSNumber
        XCTAssertEqual(viewCountValue?.intValue, 2, "Aggregated viewCount for same location")
    }

    // MARK: - Attribution Tests

    func testAttribution_TrackExperience_IncludesAssetsInXDM() {
        // Given - Register experience with assets
        let experienceId = registerExperienceAndWait(
            assets: [
                ContentItem(value: "https://example.com/hero.jpg", styles: [:]),
                ContentItem(value: "https://example.com/cta.png", styles: [:])
            ],
            texts: [ContentItem(value: "Welcome", styles: [:])],
            ctas: nil,
            location: "home"
        )
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track experience
        trackExperienceAndWait(experienceId: experienceId, interaction: .view)

        // Then - Experience event should be dispatched with correct structure
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch experience event")

        let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]

        // Verify experience ID and basic structure
        XCTAssertNotNil(experience, "Should have experience data in XDM")
        XCTAssertEqual(experience?["experienceID"] as? String, experienceId, "Should have correct experience ID")
        XCTAssertEqual(experience?["experienceChannel"] as? String, "mobile", "Should have mobile channel")

        // Verify asset attribution: Assets registered with experience should be included in XDM
        let assets = experienceContent?["assets"] as? [[String: Any]]
        XCTAssertNotNil(assets, "Experience event should include assets array")
        XCTAssertEqual(assets?.count, 2, "Should include 2 assets from experience registration")

        // Extract asset IDs and verify they match registered assets
        let assetIDs = assets?.compactMap { $0["assetID"] as? String }.sorted() ?? []
        let expectedAssetIDs = ["https://example.com/cta.png", "https://example.com/hero.jpg"]
        XCTAssertEqual(assetIDs, expectedAssetIDs, "Assets from experience registration should be attributed to experience event")
    }

    // MARK: - Configuration Change Tests

    func testConfigurationChange_UpdateExclusionPatterns_AffectsTracking() {
        // Given - Initial config with no exclusions
        sendConfiguration([
            "contentanalytics.excludedAssetUrlsRegexp": "",
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Track a .gif (not excluded yet)
        trackAssetAndWait(url: "https://example.com/animation.gif", location: "home")
        var edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch before exclusion")

        // When - Update config to exclude .gif
        sendConfiguration([
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.gif$",
            "contentanalytics.batchingEnabled": false,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Track another .gif
        trackAssetAndWait(url: "https://example.com/animation2.gif", location: "home")

        // Then - Should not dispatch
        edgeEvents = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
        XCTAssertEqual(edgeEvents.count, 0, "Should be excluded after config update")
    }

    // MARK: - Experience Extras Tests

    func testExperienceTrackingWithExtras_IncludesExtrasInXDM() {
        // Given - Register experience
        let experienceId = registerExperienceAndWait(
            assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
            texts: [ContentItem(value: "Welcome", styles: [:])],
            ctas: nil,
            location: "home"
        )
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track with extras
        let extras = ["campaign": "summer-sale", "variant": "A"] as [String: Any]
        let eventData: [String: Any] = [
            ExperienceTrackingEventPayload.RequiredFields.experienceId: experienceId,
            ExperienceTrackingEventPayload.RequiredFields.interactionType: InteractionType.view.stringValue,
            ExperienceTrackingEventPayload.OptionalFields.experienceExtras: extras
        ]

        let event = Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: eventData
        )

        mockRuntime.simulateComingEvents(event)
        Thread.sleep(forTimeInterval: 0.3)

        // Then - Extras should be in XDM
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch experience event with extras")

        let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let experience = experienceContent?["experience"] as? [String: Any]
        let experienceExtras = experience?["experienceExtras"] as? [String: Any]

        XCTAssertNotNil(experienceExtras, "Should have experienceExtras")
        XCTAssertEqual(experienceExtras?["campaign"] as? String, "summer-sale")
        XCTAssertEqual(experienceExtras?["variant"] as? String, "A")
    }

    // MARK: - Exclusion Tests

    func testExcludedAsset_NotDispatched() {
        // Given - Configuration with exclusion pattern
        sendConfiguration([
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.gif$",
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track excluded asset
        trackAssetAndWait(url: "https://example.com/animation.gif")

        // Then - No Edge event should be dispatched
        let edgeEvents = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
        XCTAssertEqual(edgeEvents.count, 0, "Excluded asset should not dispatch Edge event")
    }

    func testNonExcludedAsset_Dispatched() {
        // Given - Configuration with exclusion pattern
        sendConfiguration([
            "contentanalytics.excludedAssetUrlsRegexp": ".*\\.gif$",
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track non-excluded asset
        trackAssetAndWait(url: "https://example.com/image.jpg")

        // Then - Edge event should be dispatched
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Non-excluded asset should dispatch Edge event")
    }

    func testExcludedAssetLocation_NotDispatched() {
        // Given - Configuration with excluded asset locations (using regex)
        sendConfiguration([
            "contentanalytics.excludedAssetLocationsRegexp": "^(debug|test)$",
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track asset with excluded location
        trackAssetAndWait(url: "https://example.com/image.jpg", location: "debug")

        // Then - No Edge event should be dispatched
        let edgeEvents = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
        XCTAssertEqual(edgeEvents.count, 0, "Asset with excluded location should not dispatch Edge event")
    }

    func testNonExcludedAssetLocation_Dispatched() {
        // Given - Configuration with excluded asset locations (using regex)
        sendConfiguration([
            "contentanalytics.excludedAssetLocationsRegexp": "^(debug|test)$",
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track asset with non-excluded location
        trackAssetAndWait(url: "https://example.com/image.jpg", location: "home")

        // Then - Edge event should be dispatched
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Asset with non-excluded location should dispatch Edge event")
    }

    func testAssetNoLocation_WithExcludedLocations_Dispatched() {
        // Given - Configuration with excluded asset locations (using regex)
        sendConfiguration([
            "contentanalytics.excludedAssetLocationsRegexp": "^(debug|test)$",
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track asset without location
        trackAssetAndWait(url: "https://example.com/image.jpg")

        // Then - Edge event should be dispatched (nil location doesn't match exclusion pattern)
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Asset without location should dispatch Edge event")
    }

    func testDatastreamOverride_AppliedToEdgeEvents() {
        // Given - Configuration with custom datastream
        let customDatastreamId = "custom-content-analytics-datastream"
        sendConfiguration([
            "contentanalytics.configId": customDatastreamId,
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track asset
        trackAssetAndWait(url: "https://example.com/image.jpg", location: "home")

        // Then - Edge event should include datastream override
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch one Edge event")

        let edgeEvent = edgeEvents[0]
        let config = edgeEvent.data?["config"] as? [String: Any]
        let datastreamOverride = config?["datastreamIdOverride"] as? String

        XCTAssertNotNil(config, "Edge event should include config")
        XCTAssertEqual(datastreamOverride, customDatastreamId, "Should use custom datastream ID")
    }

    func testNoDatastreamOverride_UsesDefaultDatastream() {
        // Given - Configuration WITHOUT custom datastream
        sendConfiguration([
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Track asset
        trackAssetAndWait(url: "https://example.com/image.jpg", location: "home")

        // Then - Edge event should NOT include datastream override
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch one Edge event")

        let edgeEvent = edgeEvents[0]
        let config = edgeEvent.data?["config"] as? [String: Any]

        XCTAssertNil(config, "Edge event should not include config override when not configured")
    }

    func testDatastreamOverride_AppliedToExperienceEvents() {
        // Given - Configuration with custom datastream
        let customDatastreamId = "custom-content-analytics-datastream"
        sendConfiguration([
            "contentanalytics.configId": customDatastreamId,
            "contentanalytics.batchingEnabled": false
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // When - Register and track experience
        let assets = [ContentItem(value: "https://example.com/hero.jpg", styles: [:])]
        let texts = [ContentItem(value: "Hero Title", styles: [:])]
        let experienceId = registerExperienceAndWait(
            assets: assets,
            texts: texts,
            ctas: nil,
            location: "home"
        )
        trackExperienceAndWait(experienceId: experienceId, interaction: .view)

        // Then - Edge event should include datastream override
        let edgeEvents = waitForEdgeEvents(count: 1)
        XCTAssertEqual(edgeEvents.count, 1, "Should dispatch one Edge event")

        let edgeEvent = edgeEvents[0]
        let config = edgeEvent.data?["config"] as? [String: Any]
        let datastreamOverride = config?["datastreamIdOverride"] as? String

        XCTAssertNotNil(config, "Edge event should include config")
        XCTAssertEqual(datastreamOverride, customDatastreamId, "Should use custom datastream ID")
    }

    // MARK: - Batching Delayed Flush Test

    func testBatching_DelayedFlush_EventsAggregatedCorrectly() {
        // Verifies that config changes can trigger flush of pending batched events
        // Note: Tests in-memory flush, not crash recovery (see integration tests for that)

        // Track 2 events with high batch threshold (won't auto-flush)
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 10,
            "contentanalytics.trackExperiences": true
        ])
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        trackAssetAndWait(url: "https://example.com/hero.jpg", interaction: .view, location: "home")
        trackAssetAndWait(url: "https://example.com/hero.jpg", interaction: .view, location: "home")
        Thread.sleep(forTimeInterval: 1.5)

        var edgeEvents = mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
        XCTAssertEqual(edgeEvents.count, 0, "No events sent yet (batch not full)")

        // Lower batch threshold to trigger flush
        sendConfiguration([
            "contentanalytics.batchingEnabled": true,
            "contentanalytics.maxBatchSize": 2,
            "contentanalytics.trackExperiences": true
        ])
        Thread.sleep(forTimeInterval: 2.5)

        // Verify flush and aggregation
        edgeEvents = waitForEdgeEvents(count: 1, timeout: 3.0)
        XCTAssertEqual(edgeEvents.count, 1, "Config change triggered flush")

        let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
        let experienceContent = xdm?["experienceContent"] as? [String: Any]
        let assets = experienceContent?["assets"] as? [[String: Any]]

        XCTAssertEqual(assets?.count, 1)
        XCTAssertEqual(assets?[0]["assetID"] as? String, "https://example.com/hero.jpg")

        let assetViews = assets?[0]["assetViews"] as? [String: Any]
        let viewCount = assetViews?["value"] as? NSNumber
        XCTAssertEqual(viewCount?.intValue, 2, "2 views aggregated correctly")
        XCTAssertEqual(assets?[0]["assetSource"] as? String, "home")
    }
}
