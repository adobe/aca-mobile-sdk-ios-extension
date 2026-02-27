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

/// Tests for batch coordinator: event batching, size triggers, flush/clear operations, and thread safety.
class ContentAnalyticsBatchCoordinatorTests: XCTestCase {

    var batchCoordinator: BatchCoordinator!
    var stateManager: ContentAnalyticsStateManager!

    var assetCallbackInvoked: Bool = false
    var experienceCallbackInvoked: Bool = false
    var assetCallbackEvents: [Event] = []
    var experienceCallbackEvents: [Event] = []

    override func setUp() {
        super.setUp()

        // Create state manager
        stateManager = ContentAnalyticsStateManager()

        // Use unique queue labels per test to prevent cross-test pollution
        let testID = UUID().uuidString
        guard let assetDataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: "test.asset.\(testID)"),
              let experienceDataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: "test.experience.\(testID)") else {
            XCTFail("Failed to create data queues")
            return
        }

        // Create batch coordinator
        batchCoordinator = BatchCoordinator(
            assetDataQueue: assetDataQueue,
            experienceDataQueue: experienceDataQueue,
            state: stateManager
        )

        // Reset callback state
        assetCallbackInvoked = false
        experienceCallbackInvoked = false
        assetCallbackEvents = []
        experienceCallbackEvents = []

        // Set up callbacks
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
            }
        )
        
        // Synchronization barrier: getBatchStatus() uses batchQueue.sync, which blocks
        // until all prior async operations (including setCallbacks) complete.
        // This eliminates race conditions without changing production code or using arbitrary sleeps.
        _ = batchCoordinator.getBatchStatus()
    }

    override func tearDown() {
        batchCoordinator = nil
        stateManager = nil
        assetCallbackInvoked = false
        experienceCallbackInvoked = false
        assetCallbackEvents = []
        experienceCallbackEvents = []
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create a test asset event
    private func createAssetEvent(url: String = "https://example.com/asset.jpg") -> Event {
        return Event(
            name: "Track Asset",
            type: "com.adobe.eventType.contentAnalytics",
            source: EventSource.requestContent,
            data: [
                "assetURL": url,
                "interactionType": "view"
            ]
        )
    }

    /// Create a test experience event
    private func createExperienceEvent(id: String = "exp-123") -> Event {
        return Event(
            name: "Track Experience",
            type: "com.adobe.eventType.contentAnalytics",
            source: EventSource.requestContent,
            data: [
                "experienceId": id,
                "interactionType": "view"
            ]
        )
    }

    /// Wait for async operations
    private func waitForAsync(timeout: TimeInterval = 1.0) {
        let exp = expectation(description: "Async operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout + 1.0)
    }

    // MARK: - Event Addition Tests

    func testAddAssetEvent_SingleEvent_AddsToQueue() {
        // When
        let event = createAssetEvent()
        batchCoordinator.addAssetEvent(event)

        // Wait for async processing
        waitForAsync(timeout: 0.2)

        // Then
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 1, "Should have 1 asset event in batch")
        XCTAssertEqual(status.experienceCount, 0, "Should have 0 experience events")
    }

    func testAddExperienceEvent_SingleEvent_AddsToQueue() {
        // When
        let event = createExperienceEvent()
        batchCoordinator.addExperienceEvent(event)

        // Wait for async processing
        waitForAsync(timeout: 0.2)

        // Then
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Should have 0 asset events")
        XCTAssertEqual(status.experienceCount, 1, "Should have 1 experience event in batch")
    }

    func testAddEvents_MultipleAssets_TracksCount() {
        // When - Add 5 asset events
        for i in 0..<5 {
            let event = createAssetEvent(url: "https://example.com/asset\(i).jpg")
            batchCoordinator.addAssetEvent(event)
        }

        // Wait for async processing
        waitForAsync(timeout: 0.3)

        // Then
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 5, "Should have 5 asset events in batch")
    }

    func testAddEvents_MultipleExperiences_TracksCount() {
        // When - Add 5 experience events
        for i in 0..<5 {
            let event = createExperienceEvent(id: "exp-\(i)")
            batchCoordinator.addExperienceEvent(event)
        }

        // Wait for async processing
        waitForAsync(timeout: 0.3)

        // Then
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.experienceCount, 5, "Should have 5 experience events in batch")
    }

    func testAddEvents_MixedTypes_TracksIndependently() {
        // When - Add both asset and experience events
        for i in 0..<3 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
            batchCoordinator.addExperienceEvent(createExperienceEvent(id: "exp-\(i)"))
        }

        // Wait for async processing
        waitForAsync(timeout: 0.3)

        // Then
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 3, "Should have 3 asset events")
        XCTAssertEqual(status.experienceCount, 3, "Should have 3 experience events")
    }

    // MARK: - Batch Size Trigger Tests

    func testBatchSize_ReachesThreshold_TriggersBatch() {
        // Given - Callback to capture flush
        let batchSize = 10

        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding

        // When - Add exactly 10 events (reaches threshold, triggers flush)
        for i in 0..<batchSize {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        // Wait for batch to flush by polling (avoids flaky expectation from callback on background queue)
        let flushTimeout = 15.0
        let pollInterval = 0.05
        var elapsed: TimeInterval = 0
        while elapsed < flushTimeout {
            let status = batchCoordinator.getBatchStatus()
            if status.assetCount == 0 { break }
            Thread.sleep(forTimeInterval: pollInterval)
            elapsed += pollInterval
        }

        // Then - Batch should have been flushed
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Batch should be flushed when reaching threshold (waited \(elapsed)s)")
        XCTAssertTrue(assetCallbackInvoked, "Asset callback should be invoked")
    }

    func testBatchSize_BelowThreshold_DoesNotTrigger() {
        // Given - Default batch size is 10
        let belowThreshold = 5

        // When - Add fewer than batch size
        for i in 0..<belowThreshold {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        // Wait briefly
        waitForAsync(timeout: 0.2)

        // Then - Batch should NOT be flushed yet
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, belowThreshold, "Batch should not flush below threshold")
        XCTAssertFalse(assetCallbackInvoked, "Callback should not be invoked yet")
    }

    func testBatchSize_ExceedsThreshold_TriggersBatch() {
        // Given - Default batch size is 10
        let exceedThreshold = 12

        // When - Add more than batch size
        for i in 0..<exceedThreshold {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        // Wait for batch processing
        waitForAsync(timeout: 0.5)

        // Then - Batch should have been flushed
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 2, "Should have 2 remaining events after first batch flush")
        XCTAssertTrue(assetCallbackInvoked, "Asset callback should be invoked")
    }

    func testBatchSize_MixedEvents_CountsCombined() {
        // Given - Default batch size is 10
        // When - Add 5 assets + 5 experiences = 10 total
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
            batchCoordinator.addExperienceEvent(createExperienceEvent(id: "exp-\(i)"))
        }

        // Wait for batch processing
        waitForAsync(timeout: 0.5)

        // Then - Batch should be flushed (combined count = 10)
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Asset batch should be flushed")
        XCTAssertEqual(status.experienceCount, 0, "Experience batch should be flushed")
    }

    // MARK: - Configuration Update Tests

    func testUpdateConfiguration_SmallerBatchSize_TriggersFlush() {
        // Given - Add 8 events (below default threshold of 10)
        for i in 0..<8 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        // Verify not flushed yet
        var status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 8, "Should have 8 events before config update")

        // Set up expectation and callback BEFORE triggering flush
        let expectation = XCTestExpectation(description: "Configuration update triggers flush")
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
                expectation.fulfill()
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding
        
        // When - Update to smaller batch size (should trigger flush since 8 > 5)
        let newConfig = BatchingConfiguration(
            maxBatchSize: 5,
            flushIntervalMs: 2000,
            maxWaitTimeMs: 5000
        )
        batchCoordinator.updateConfiguration(newConfig)

        // Wait for flush callback
        wait(for: [expectation], timeout: 10.0)

        // Then - Should have flushed since 8 > new threshold of 5
        status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Should flush when new batch size is smaller than current count")
        XCTAssertTrue(assetCallbackInvoked, "Callback should be invoked")
    }

    func testUpdateConfiguration_LargerBatchSize_DoesNotFlush() {
        // Given - Add 5 events
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        waitForAsync(timeout: 0.2)

        // When - Update to larger batch size
        let newConfig = BatchingConfiguration(
            maxBatchSize: 20,
            flushIntervalMs: 2000,
            maxWaitTimeMs: 5000
        )
        batchCoordinator.updateConfiguration(newConfig)

        // Wait briefly
        waitForAsync(timeout: 0.2)

        // Then - Should NOT flush
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 5, "Should not flush when new batch size is larger")
        XCTAssertFalse(assetCallbackInvoked, "Callback should not be invoked")
    }

    // MARK: - Flush Operation Tests

    func testFlush_WithPendingEvents_DispatchesAll() {
        // Given - Add some events
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }
        
        // Set up expectation and callback BEFORE triggering flush
        let expectation = XCTestExpectation(description: "Flush callback invoked")
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
                expectation.fulfill()
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding

        // When - Manually flush
        batchCoordinator.flush()

        // Wait for flush callback
        wait(for: [expectation], timeout: 10.0)

        // Then - All events should be dispatched
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "All events should be flushed")
        XCTAssertTrue(assetCallbackInvoked, "Callback should be invoked")
    }

    func testFlush_EmptyBatch_HandlesGracefully() {
        // When - Flush with no events
        batchCoordinator.flush()

        // Wait briefly
        waitForAsync(timeout: 0.2)

        // Then - Should handle gracefully (no crash)
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Should remain at 0")
        XCTAssertEqual(status.experienceCount, 0, "Should remain at 0")
        // Success: empty flush handled without crash
    }

    func testFlush_MultipleTimes_HandlesGracefully() {
        // Given - Add events
        for i in 0..<3 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        waitForAsync(timeout: 0.2)

        // When - Flush multiple times
        batchCoordinator.flush()
        batchCoordinator.flush()
        batchCoordinator.flush()

        // Wait for all flushes
        waitForAsync(timeout: 0.5)

        // Then - Should handle gracefully
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Should be flushed")
        // Success: multiple flushes handled without crash
    }

    // MARK: - Clear Operation Tests

    func testClear_WithPendingEvents_ClearsWithoutSending() {
        // Given - Add events
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        waitForAsync(timeout: 0.2)

        // When - Clear
        batchCoordinator.clearPendingBatch()

        // Wait for clear
        waitForAsync(timeout: 0.2)

        // Then - Events should be cleared without invoking callback
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Events should be cleared")
        XCTAssertFalse(assetCallbackInvoked, "Callback should NOT be invoked on clear")
    }

    func testClear_EmptyBatch_HandlesGracefully() {
        // When - Clear with no events
        batchCoordinator.clearPendingBatch()

        // Wait briefly
        waitForAsync(timeout: 0.2)

        // Then - Should handle gracefully
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Should remain at 0")
        XCTAssertEqual(status.experienceCount, 0, "Should remain at 0")
        // Success: empty clear handled without crash
    }

    // MARK: - Callback Tests

    func testCallbacks_AssetEvents_InvokesAssetCallback() {
        // Given - Expectation for callback
        let expectation = XCTestExpectation(description: "Asset callback invoked")
        
        // Set up callback with expectation
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
                expectation.fulfill()
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding
        
        // When - Add asset events (10 = threshold, triggers flush)
        for i in 0..<10 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        // Wait for callback (returns immediately when fulfilled, max 10s timeout)
        wait(for: [expectation], timeout: 10.0)

        // Then
        XCTAssertTrue(assetCallbackInvoked, "Asset callback should be invoked")
        XCTAssertFalse(experienceCallbackInvoked, "Experience callback should NOT be invoked")
    }

    func testCallbacks_ExperienceEvents_InvokesExperienceCallback() {
        // Given - Expectation for callback
        let expectation = XCTestExpectation(description: "Experience callback invoked")
        
        // Set up callback with expectation
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
                expectation.fulfill()
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding
        
        // When - Add experience events (10 = threshold, triggers flush)
        for i in 0..<10 {
            batchCoordinator.addExperienceEvent(createExperienceEvent(id: "exp-\(i)"))
        }

        // Wait for callback (returns immediately when fulfilled, max 5s timeout)
        wait(for: [expectation], timeout: 5.0)

        // Then
        XCTAssertFalse(assetCallbackInvoked, "Asset callback should NOT be invoked")
        XCTAssertTrue(experienceCallbackInvoked, "Experience callback should be invoked")
    }

    func testCallbacks_MixedEvents_InvokesBothCallbacks() {
        // Given - Expectations for both callbacks
        let assetExpectation = XCTestExpectation(description: "Asset callback invoked")
        let experienceExpectation = XCTestExpectation(description: "Experience callback invoked")
        
        // Set up callbacks with expectations
        batchCoordinator.setCallbacks(
            assetCallback: { [weak self] events in
                self?.assetCallbackInvoked = true
                self?.assetCallbackEvents.append(contentsOf: events)
                assetExpectation.fulfill()
            },
            experienceCallback: { [weak self] events in
                self?.experienceCallbackInvoked = true
                self?.experienceCallbackEvents.append(contentsOf: events)
                experienceExpectation.fulfill()
            }
        )
        _ = batchCoordinator.getBatchStatus() // Ensure callbacks are set before proceeding
        
        // When - Add mixed events (5 assets + 5 experiences = 10 total = threshold)
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
            batchCoordinator.addExperienceEvent(createExperienceEvent(id: "exp-\(i)"))
        }

        // Wait for both callbacks (returns immediately when fulfilled, max 10s timeout)
        wait(for: [assetExpectation, experienceExpectation], timeout: 10.0)

        // Then
        XCTAssertTrue(assetCallbackInvoked, "Asset callback should be invoked")
        XCTAssertTrue(experienceCallbackInvoked, "Experience callback should be invoked")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess_AssetEventAddition_ThreadSafe() {
        // Given
        let iterations = 50
        let expectation = XCTestExpectation(description: "All concurrent operations complete")
        expectation.expectedFulfillmentCount = iterations

        // When - Add events concurrently from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let event = self.createAssetEvent(url: "https://example.com/asset\(i).jpg")
                self.batchCoordinator.addAssetEvent(event)
                expectation.fulfill()
            }
        }

        // Then - Should complete without crashes
        wait(for: [expectation], timeout: 5.0)

        // Wait for all async operations to settle
        waitForAsync(timeout: 0.5)

        // Verify state is valid (some events may have been flushed)
        let status = batchCoordinator.getBatchStatus()
        XCTAssertTrue(status.assetCount >= 0, "Should have valid asset count")
        // Success: concurrent operations handled without crash
    }

    func testConcurrentAccess_MixedOperations_ThreadSafe() {
        // Given
        let iterations = 100
        let expectation = XCTestExpectation(description: "All mixed operations complete")
        expectation.expectedFulfillmentCount = iterations

        // When - Mix of adds, flushes, and clears from multiple threads
        for i in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                switch i % 4 {
                case 0:
                    self.batchCoordinator.addAssetEvent(self.createAssetEvent())
                case 1:
                    self.batchCoordinator.addExperienceEvent(self.createExperienceEvent())
                case 2:
                    self.batchCoordinator.flush()
                case 3:
                    _ = self.batchCoordinator.getBatchStatus()
                default:
                    break
                }
                expectation.fulfill()
            }
        }

        // Then - Should complete without crashes or data corruption
        wait(for: [expectation], timeout: 10.0)
        // Success: concurrent mixed operations handled without crash
    }

    // MARK: - Edge Case Tests

    func testGetBatchStatus_ReturnsCurrentState() {
        // Given - Add some events
        for i in 0..<3 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }
        for i in 0..<2 {
            batchCoordinator.addExperienceEvent(createExperienceEvent(id: "exp-\(i)"))
        }

        // Wait for async processing
        waitForAsync(timeout: 0.2)

        // When
        let status = batchCoordinator.getBatchStatus()

        // Then
        XCTAssertEqual(status.assetCount, 3, "Should return correct asset count")
        XCTAssertEqual(status.experienceCount, 2, "Should return correct experience count")
    }

    func testBatchCoordinator_AfterFlush_ResetsState() {
        // Given - Add events and flush
        for i in 0..<10 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        waitForAsync(timeout: 0.5)

        // Then - State should be reset
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Asset count should be reset after flush")
        XCTAssertEqual(status.experienceCount, 0, "Experience count should be reset after flush")
    }

    func testBatchCoordinator_AfterClear_ResetsState() {
        // Given - Add events and clear
        for i in 0..<5 {
            batchCoordinator.addAssetEvent(createAssetEvent(url: "https://example.com/asset\(i).jpg"))
        }

        waitForAsync(timeout: 0.2)

        batchCoordinator.clearPendingBatch()
        waitForAsync(timeout: 0.2)

        // Then - State should be reset
        let status = batchCoordinator.getBatchStatus()
        XCTAssertEqual(status.assetCount, 0, "Asset count should be reset after clear")
        XCTAssertEqual(status.experienceCount, 0, "Experience count should be reset after clear")
    }
}
