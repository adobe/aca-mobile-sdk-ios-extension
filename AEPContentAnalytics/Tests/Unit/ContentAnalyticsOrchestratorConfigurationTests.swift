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

/// Tests for orchestrator configuration handling: batching behavior and dynamic updates.
/// BatchCoordinator internals tested separately in ContentAnalyticsBatchCoordinatorTests.
final class ContentAnalyticsOrchestratorConfigurationTests: ContentAnalyticsOrchestratorTestBase {

    // All setup/teardown handled by base class!
    // Available properties:
    // - orchestrator
    // - mockStateManager
    // - mockBatchCoordinator
    // - mockEventDispatcher
    // - mockPrivacyValidator
    // - mockXDMBuilder

    // MARK: - Batching Disabled Tests

    func testBatchingDisabled_AssetEventSentImmediately() {
        // Given - Configuration with batching disabled
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedAssetUrlsRegexp = nil // Allow all assets
        mockStateManager.updateConfiguration(config)

        // When - Process an asset event
        let trackEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(trackEvent) { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then - Event should be dispatched immediately (NOT added to batch)
        XCTAssertEqual(
            mockBatchCoordinator.assetEvents.count,
            0,
            "With batching disabled, events should NOT go to batch coordinator"
        )

        // Verify event was dispatched directly
        XCTAssertTrue(
            mockEventDispatcher.eventDispatched,
            "Event should be dispatched immediately when batching disabled"
        )
    }

    func testBatchingDisabled_MultipleEventsEachSentImmediately() {
        // Given - Configuration with batching disabled
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedAssetUrlsRegexp = nil // Allow all assets
        mockStateManager.updateConfiguration(config)

        let expectation = self.expectation(description: "Events processed")
        expectation.expectedFulfillmentCount = 3

        // When - Process multiple asset events
        for i in 1...3 {
            let trackEvent = TestEventFactory.createAssetEvent(
                url: "https://example.com/image\(i).jpg",
                location: "home",
                interaction: .view
            )
            orchestrator.processAssetEvent(trackEvent) { _ in
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)

        // Then - All events should be sent immediately (NOT batched)
        XCTAssertEqual(
            mockBatchCoordinator.assetEvents.count,
            0,
            "With batching disabled, no events should go to batch coordinator"
        )

        // Each event should be dispatched
        XCTAssertEqual(
            mockEventDispatcher.dispatchedEvents.count,
            3,
            "Each event should be dispatched immediately"
        )
    }

    // MARK: - Batching Enabled Tests

    func testBatchingEnabled_EventsAddedToBatchCoordinator() {
        // Given - Configuration with batching enabled
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = 10
        config.excludedAssetUrlsRegexp = nil // Allow all assets
        mockStateManager.updateConfiguration(config)

        let expectation = self.expectation(description: "Events processed")
        expectation.expectedFulfillmentCount = 3

        // When - Process 3 asset events (below batch size)
        for i in 1...3 {
            let trackEvent = TestEventFactory.createAssetEvent(
                url: "https://example.com/image\(i).jpg",
                location: "home",
                interaction: .view
            )
            orchestrator.processAssetEvent(trackEvent) { _ in
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)

        // Then - Events should be added to batch coordinator (NOT sent immediately)
        XCTAssertEqual(
            mockBatchCoordinator.assetEvents.count,
            3,
            "With batching enabled, events should be added to batch coordinator"
        )

        // Events should NOT be dispatched immediately
        XCTAssertEqual(
            mockEventDispatcher.dispatchedEvents.count,
            0,
            "Events should NOT be dispatched immediately when batching enabled"
        )
    }

    func testBatchingEnabled_ExperienceEventsAddedToBatchCoordinator() {
        // Given - Configuration with batching enabled
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.trackExperiences = true
        config.excludedExperienceLocationsRegexp = nil // Allow all experience locations
        mockStateManager.updateConfiguration(config)

        // Register experiences in state first
        let exp1Assets = ["https://example.com/image1.jpg"]
        let exp1Text = [ContentItem(value: "Test 1", styles: [:])]
        let exp1Id = ContentAnalyticsUtilities.generateExperienceId(
            from: exp1Assets.map { ContentItem(value: $0, styles: [:]) },
            texts: exp1Text,
            ctas: nil
        )
        mockStateManager.storeExperienceDefinition(
            experienceId: exp1Id,
            assets: exp1Assets,
            texts: exp1Text,
            ctas: nil
        )

        let exp2Assets = ["https://example.com/image2.jpg"]
        let exp2Text = [ContentItem(value: "Test 2", styles: [:])]
        let exp2Id = ContentAnalyticsUtilities.generateExperienceId(
            from: exp2Assets.map { ContentItem(value: $0, styles: [:]) },
            texts: exp2Text,
            ctas: nil
        )
        mockStateManager.storeExperienceDefinition(
            experienceId: exp2Id,
            assets: exp2Assets,
            texts: exp2Text,
            ctas: nil
        )

        let expectation = self.expectation(description: "Events processed")
        expectation.expectedFulfillmentCount = 2

        // When - Process experience events
        let trackEvent1 = TestEventFactory.createExperienceEvent(
            id: exp1Id,
            location: "home",
            interaction: .view
        )
        orchestrator.processExperienceEvent(trackEvent1) { _ in
            expectation.fulfill()
        }

        let trackEvent2 = TestEventFactory.createExperienceEvent(
            id: exp2Id,
            location: "home",
            interaction: .view
        )
        orchestrator.processExperienceEvent(trackEvent2) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Then - Experience events should be added to batch coordinator
        XCTAssertEqual(
            mockBatchCoordinator.experienceEvents.count,
            2,
            "Experience events should be added to batch coordinator"
        )

        // Events should NOT be dispatched immediately
        XCTAssertEqual(
            mockEventDispatcher.dispatchedEvents.count,
            0,
            "Experience events should NOT be dispatched immediately when batching enabled"
        )
    }

    // MARK: - Configuration Change Tests

    func testToggleBatching_EnabledToDisabled_FlushesBatchCoordinator() {
        // Given - Start with batching enabled and some queued events
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.excludedAssetUrlsRegexp = nil // Allow all assets
        mockStateManager.updateConfiguration(config)

        // Process an event to add to batch
        let trackEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/batch1.jpg",
            location: "home",
            interaction: .view
        )

        let expectation1 = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(trackEvent) { _ in
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Verify event is in batch
        XCTAssertEqual(mockBatchCoordinator.assetEvents.count, 1, "Event should be in batch")

        // When - Disable batching via orchestrator configuration update
        // Note: Don't update mockStateManager first - orchestrator needs to detect the change
        // from the current state (true) to the new config (false)
        config.batchingEnabled = false
        orchestrator.updateConfiguration(config)

        // Update state manager to reflect the change (for subsequent tests)
        mockStateManager.updateConfiguration(config)

        // Then - Batch coordinator should be automatically flushed
        XCTAssertTrue(
            mockBatchCoordinator.flushCalled,
            "Batch coordinator should be automatically flushed when batching is disabled"
        )
    }

    func testConfigurationUpdate_UpdatesBatchCoordinatorSettings() {
        // Given - Initial configuration
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = 10
        mockStateManager.updateConfiguration(config)

        // When - Update configuration with different batch size
        let newBatchConfig = BatchingConfiguration(
            maxBatchSize: 5,
            flushInterval: 2.0,
            maxWaitTime: 5.0
        )
        mockBatchCoordinator.updateConfiguration(newBatchConfig)

        // Then - Batch coordinator should be updated
        XCTAssertTrue(
            mockBatchCoordinator.updateConfigurationCalled,
            "Batch coordinator configuration should be updated"
        )

        XCTAssertEqual(
            mockBatchCoordinator.configuration?.maxBatchSize,
            5,
            "Batch size should be updated to 5"
        )
    }
}
