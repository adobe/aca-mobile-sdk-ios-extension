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

// MARK: - Test Base Class

/// Base test class with common setup and utilities
/// Use this as your test superclass to get automatic setup/teardown and helper methods
class ContentAnalyticsTestBase: XCTestCase {

    // MARK: - Properties

    var mockRuntime: TestableExtensionRuntime!
    var contentAnalytics: ContentAnalytics!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        mockRuntime = TestableExtensionRuntime()
        contentAnalytics = ContentAnalytics(runtime: mockRuntime)
        contentAnalytics.onRegistered()
    }

    override func tearDown() {
        mockRuntime?.resetDispatchedEventAndCreatedSharedStates()
        contentAnalytics?.onUnregistered()
        contentAnalytics = nil
        mockRuntime = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Wait for async operations with shorter timeout for tests
    func waitForAsync(timeout: TimeInterval = 0.5, file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Async operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout + 0.5)
    }

    /// Get the first dispatched event matching criteria
    func getFirstEvent(withName name: String? = nil, type: String? = nil) -> Event? {
        return mockRuntime.dispatchedEvents.first { event in
            if let name = name, event.name != name { return false }
            if let type = type, event.type != type { return false }
            return true
        }
    }

    /// Get all dispatched events matching criteria
    func getEvents(withName name: String? = nil, type: String? = nil) -> [Event] {
        return mockRuntime.dispatchedEvents.filter { event in
            if let name = name, event.name != name { return false }
            if let type = type, event.type != type { return false }
            return true
        }
    }

    /// Clear all dispatched events
    func clearDispatchedEvents() {
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
    }
}

// MARK: - Event Assertions

extension XCTestCase {

    /// Assert that an event was dispatched with expected properties
    func assertEventDispatched(
        events: [Event],
        name: String? = nil,
        type: String? = nil,
        source: String? = nil,
        expectedData: [String: Any]? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let matchingEvents = events.filter { event in
            if let name = name, event.name != name { return false }
            if let type = type, event.type != type { return false }
            if let source = source, event.source != source { return false }
            return true
        }

        XCTAssertFalse(matchingEvents.isEmpty,
                      "Expected event with name: \(name ?? "any"), type: \(type ?? "any") not found",
                      file: file, line: line)

        if let expectedData = expectedData, let event = matchingEvents.first {
            assertEventData(event: event, expectedData: expectedData, file: file, line: line)
        }
    }

    /// Assert event data contains expected key-value pairs
    func assertEventData(
        event: Event,
        expectedData: [String: Any],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let actualData = event.data else {
            XCTFail("Event has no data", file: file, line: line)
            return
        }

        for (key, expectedValue) in expectedData {
            guard let actualValue = actualData[key] else {
                XCTFail("Event data missing key '\(key)'", file: file, line: line)
                continue
            }

            assertValuesEqual(actualValue, expectedValue, key: key, file: file, line: line)
        }
    }

    /// Compare two values (handles various types)
    private func assertValuesEqual(
        _ actual: Any,
        _ expected: Any,
        key: String,
        file: StaticString,
        line: UInt
    ) {
        if let actualString = actual as? String, let expectedString = expected as? String {
            XCTAssertEqual(actualString, expectedString,
                          "Event data[\(key)] mismatch", file: file, line: line)
        } else if let actualInt = actual as? Int, let expectedInt = expected as? Int {
            XCTAssertEqual(actualInt, expectedInt,
                          "Event data[\(key)] mismatch", file: file, line: line)
        } else if let actualBool = actual as? Bool, let expectedBool = expected as? Bool {
            XCTAssertEqual(actualBool, expectedBool,
                          "Event data[\(key)] mismatch", file: file, line: line)
        } else if let actualDouble = actual as? Double, let expectedDouble = expected as? Double {
            XCTAssertEqual(actualDouble, expectedDouble, accuracy: 0.001,
                          "Event data[\(key)] mismatch", file: file, line: line)
        }
        // Add more type comparisons as needed
    }

    /// Assert no events were dispatched
    func assertNoEventsDispatched(
        _ events: [Event],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(events.isEmpty, "Expected no events but found \(events.count)", file: file, line: line)
    }

    /// Assert exact event count
    func assertEventCount(
        _ events: [Event],
        count: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(events.count, count,
                      "Expected \(count) events but found \(events.count)",
                      file: file, line: line)
    }
}

// MARK: - Configuration Helpers

extension XCTestCase {

    /// Create a standard test configuration
    func makeTestConfiguration(
        enabled: Bool = true,
        batchingEnabled: Bool = true,
        maxBatchSize: Int = 10,
        debugLogging: Bool = false
    ) -> [String: Any] {
        return [
            "contentanalytics.enabled": enabled,
            "contentanalytics.batchingEnabled": batchingEnabled,
            "contentanalytics.maxBatchSize": maxBatchSize,
            "contentanalytics.debugLogging": debugLogging
        ]
    }

    /// Create configuration with Adobe Edge properties
    func makeEdgeConfiguration(
        orgId: String = "TEST_ORG@AdobeOrg",
        datastreamId: String = "test-datastream-id",
        environment: String = "prod"
    ) -> [String: Any] {
        var config = makeTestConfiguration()
        config["experienceCloud.org"] = orgId
        config["edge.configId"] = datastreamId
        config["edge.environment"] = environment
        return config
    }
}

// MARK: - Test Data Builders

/// Builder for creating test Events
struct TestEventBuilder {
    private var name: String = "test-event"
    private var type: String = "test-type"
    private var source: String = EventSource.requestContent
    private var data: [String: Any] = [:]

    func withName(_ name: String) -> TestEventBuilder {
        var builder = self
        builder.name = name
        return builder
    }

    func withType(_ type: String) -> TestEventBuilder {
        var builder = self
        builder.type = type
        return builder
    }

    func withSource(_ source: String) -> TestEventBuilder {
        var builder = self
        builder.source = source
        return builder
    }

    func withData(_ data: [String: Any]) -> TestEventBuilder {
        var builder = self
        builder.data = data
        return builder
    }

    func addData(key: String, value: Any) -> TestEventBuilder {
        var builder = self
        builder.data[key] = value
        return builder
    }

    func build() -> Event {
        return Event(name: name, type: type, source: source, data: data)
    }
}

/// Builder for creating test asset tracking events
struct AssetEventBuilder {
    private var assetURL: String = "https://example.com/image.jpg"
    private var interactionType: String = "view"
    private var assetLocation: String?
    private var additionalData: [String: Any]?

    static func assetView(url: String = "https://example.com/image.jpg") -> AssetEventBuilder {
        return AssetEventBuilder(assetURL: url, interactionType: "view")
    }

    static func assetClick(url: String = "https://example.com/image.jpg") -> AssetEventBuilder {
        return AssetEventBuilder(assetURL: url, interactionType: "click")
    }

    func withLocation(_ location: String) -> AssetEventBuilder {
        var builder = self
        builder.assetLocation = location
        return builder
    }

    func withAdditionalData(_ data: [String: Any]) -> AssetEventBuilder {
        var builder = self
        builder.additionalData = data
        return builder
    }

    func build() -> Event {
        var data: [String: Any] = [
            "assetURL": assetURL,
            "interactionType": interactionType
        ]

        if let location = assetLocation {
            data["assetLocation"] = location
        }

        if let additional = additionalData {
            data["additionalData"] = additional
        }

        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_ASSET,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: data
        )
    }
}

/// Builder for creating test experience events
struct ExperienceEventBuilder {
    private var experienceId: String = "exp-123"
    private var experienceLocation: String = "home"
    private var interactionType: String = "view"
    private var additionalData: [String: Any]?

    static func experienceView(id: String = "exp-123", location: String = "home") -> ExperienceEventBuilder {
        return ExperienceEventBuilder(experienceId: id, experienceLocation: location, interactionType: "view")
    }

    static func experienceClick(id: String = "exp-123", location: String = "home") -> ExperienceEventBuilder {
        return ExperienceEventBuilder(experienceId: id, experienceLocation: location, interactionType: "click")
    }

    func withAdditionalData(_ data: [String: Any]) -> ExperienceEventBuilder {
        var builder = self
        builder.additionalData = data
        return builder
    }

    func build() -> Event {
        var data: [String: Any] = [
            "experienceId": experienceId,
            "experienceLocation": experienceLocation,
            "interactionType": interactionType
        ]

        if let additional = additionalData {
            data["additionalData"] = additional
        }

        return Event(
            name: ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE,
            type: ContentAnalyticsConstants.EventType.contentAnalytics,
            source: EventSource.requestContent,
            data: data
        )
    }
}

// MARK: - Async Testing Helpers

extension XCTestCase {

    /// Wait for a condition to be true
    func waitFor(
        condition: @escaping () -> Bool,
        timeout: TimeInterval = 1.0,
        description: String = "Condition",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let exp = expectation(description: description)
        let startTime = Date()

        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                exp.fulfill()
            } else if Date().timeIntervalSince(startTime) > timeout {
                timer.invalidate()
                XCTFail("Timeout waiting for: \(description)", file: file, line: line)
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: timeout + 0.5)
    }

    /// Wait for events to be dispatched
    func waitForEvents(
        count: Int,
        in events: @escaping @autoclosure () -> [Event],
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        waitFor(
            condition: { events().count >= count },
            timeout: timeout,
            description: "Waiting for \(count) events",
            file: file,
            line: line
        )
    }
}

// MARK: - Thread Safety Testing Helpers

extension XCTestCase {

    /// Run a block concurrently and wait for completion
    func runConcurrently(
        iterations: Int,
        block: @escaping (Int) -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let exp = expectation(description: "Concurrent operations")

        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterations, execute: block)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }
}
