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
import Foundation
import XCTest

/// Helper utilities for integration testing with real disk I/O and persistence
enum IntegrationTestHelpers {

    // MARK: - Test Data Directory Management

    /// Creates a unique temporary directory for test data
    static func createTestDataDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("ContentAnalyticsTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }

    /// Cleans up test data directory
    static func cleanupTestDataDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - DataQueue Helpers

    /// Creates a real DataQueue for testing with custom directory
    static func createTestDataQueue(name: String, dataDirectory: URL) -> DataQueue {
        // DataQueue is created through ServiceProvider
        let dataQueueService = ServiceProvider.shared.dataQueueService
        guard let dataQueue = dataQueueService.getDataQueue(label: name) else {
            fatalError("Failed to create DataQueue with label: \(name)")
        }
        return dataQueue
    }

    /// Verifies that data was written to disk
    static func verifyDataWrittenToDisk(in directory: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return !contents.isEmpty
    }

    /// Counts the number of files in a directory
    static func countFilesInDirectory(_ directory: URL) -> Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }
        return contents.count
    }

    // MARK: - PersistentHitQueue Helpers

    /// Creates a real PersistentHitQueue for testing
    static func createTestPersistentQueue(
        name: String,
        dataDirectory: URL,
        processor: HitProcessing
    ) -> PersistentHitQueue {
        let dataQueue = createTestDataQueue(name: name, dataDirectory: dataDirectory)
        return PersistentHitQueue(
            dataQueue: dataQueue,
            processor: processor
        )
    }

    // MARK: - Async Test Helpers

    /// Waits for a condition with timeout
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollingInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: pollingInterval)
        }

        return false
    }

    /// Waits for async operation to complete
    static func waitForAsyncOperation(
        timeout: TimeInterval = 5.0,
        operation: (@escaping () -> Void) -> Void
    ) -> Bool {
        let expectation = XCTestExpectation(description: "Async operation")

        operation {
            expectation.fulfill()
        }

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Event Verification Helpers

    /// Captures dispatched events for verification
    class EventCapture {
        var capturedEvents: [Event] = []
        private let lock = NSLock()

        func capture(_ event: Event) {
            lock.lock()
            defer { lock.unlock() }
            capturedEvents.append(event)
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            capturedEvents.removeAll()
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return capturedEvents.count
        }
    }

    // MARK: - Crash Simulation

    /// Simulates a crash by creating a new coordinator with the same persistence directory
    static func simulateCrashRecovery(
        dataDirectory: URL,
        setupNewCoordinator: (URL) -> Void
    ) {
        // Existing coordinator is "crashed" (deallocated)
        // Create new coordinator with same data directory to test recovery
        setupNewCoordinator(dataDirectory)
    }
}

// MARK: - Custom HitProcessor for Testing

/// Test hit processor that captures events for verification
class TestHitProcessor: HitProcessing {
    let eventCapture: IntegrationTestHelpers.EventCapture
    var processHitCallback: ((DataEntity) -> Void)?

    init(eventCapture: IntegrationTestHelpers.EventCapture) {
        self.eventCapture = eventCapture
    }

    /// Retry interval for failed hits (not used in tests)
    /// - Parameter entity: The data entity
    /// - Returns: 0 (no retries in tests)
    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return 0
    }

    /// Process a hit from the persistent queue
    /// - Parameters:
    ///   - entity: The data entity containing the persisted event
    ///   - completion: Completion handler indicating success
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        // Decode the event
        if let eventData = entity.data,
           let eventWrapper = try? JSONDecoder().decode(EventWrapper.self, from: eventData) {
            eventCapture.capture(eventWrapper.event)
        }

        // Call optional callback for custom verification
        processHitCallback?(entity)

        // Always succeed for testing
        completion(true)
    }
}

/// Wrapper for serializing events to disk (matches DirectHitProcessor format)
struct EventWrapper: Codable {
    let event: Event
    let type: String
}

// MARK: - Integration Test Base Class

/// Base class for integration tests with common setup/teardown
class ContentAnalyticsIntegrationTestBase: XCTestCase {

    var testDataDirectory: URL!
    var eventCapture: IntegrationTestHelpers.EventCapture!

    override func setUp() {
        super.setUp()
        testDataDirectory = IntegrationTestHelpers.createTestDataDirectory()
        eventCapture = IntegrationTestHelpers.EventCapture()
    }

    override func tearDown() {
        if let directory = testDataDirectory {
            IntegrationTestHelpers.cleanupTestDataDirectory(directory)
        }
        testDataDirectory = nil
        eventCapture = nil
        super.tearDown()
    }

    /// Creates a test batch coordinator with real persistence
    func createTestBatchCoordinator(
        configuration: BatchingConfiguration = .default
    ) -> BatchCoordinator {
        let assetQueue = IntegrationTestHelpers.createTestDataQueue(
            name: "test-asset-queue",
            dataDirectory: testDataDirectory
        )
        let experienceQueue = IntegrationTestHelpers.createTestDataQueue(
            name: "test-experience-queue",
            dataDirectory: testDataDirectory
        )

        // Create state manager with test configuration
        let stateManager = ContentAnalyticsStateManager()
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = configuration.maxBatchSize
        config.batchFlushInterval = configuration.flushInterval
        stateManager.updateConfiguration(config)

        let coordinator = BatchCoordinator(
            assetDataQueue: assetQueue,
            experienceDataQueue: experienceQueue,
            state: stateManager
        )

        return coordinator
    }
}
