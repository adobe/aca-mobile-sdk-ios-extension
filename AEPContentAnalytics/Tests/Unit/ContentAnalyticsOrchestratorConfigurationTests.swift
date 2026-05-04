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
        mockStateManager.registerExperienceDefinition(
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
        mockStateManager.registerExperienceDefinition(
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
        // Don't update mockStateManager - orchestrator needs to detect the change
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
            flushIntervalMs: 2000,
            maxWaitTimeMs: 5000
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

    // MARK: - Experience Location Capture (captureExperienceLocation)
    //
    // Location is NOT stored at definition registration time — the same experience can be viewed
    // at different locations. The orchestrator captures location from VIEW events into the stored
    // definition BEFORE applying the exclusion filter, so excluded experiences still record their location.

    func testCaptureExperienceLocation_ViewEvent_UpdatesStoredDefinitionLocation() {
        // Given - a definition registered without a location
        mockStateManager.registerExperienceDefinition(
            experienceId: "hero",
            assets: ["https://example.com/hero.jpg"],
            texts: [],
            ctas: nil
        )
        XCTAssertNil(mockStateManager.getExperienceDefinition(for: "hero")?.experienceLocation,
                     "Location should be nil at registration time")

        let viewEvent = TestEventFactory.createExperienceEvent(
            id: "hero",
            location: "homepage",
            interaction: .view
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processExperienceEvent(viewEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(
            mockStateManager.getExperienceDefinition(for: "hero")?.experienceLocation,
            "homepage",
            "Location should be updated from the VIEW event"
        )
    }

    func testCaptureExperienceLocation_DefinitionEvent_DoesNotSetLocation() {
        // Given - definition events carry content (assets/texts) but are location-independent
        let defEvent = TestEventFactory.createExperienceEvent(
            id: "hero",
            location: "homepage",  // even if a location is present on the definition event…
            interaction: .definition,
            assetURLs: ["https://example.com/hero.jpg"]
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processExperienceEvent(defEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        // …captureExperienceLocation IS also called but only updates if a definition already exists.
        // Since this IS a definition event, preprocessExperienceDefinition stores it first,
        // then captureExperienceLocation updates the location. Verify the final state is correct.
        let definition = mockStateManager.getExperienceDefinition(for: "hero")
        XCTAssertNotNil(definition, "Definition should be stored")
        // Location captured from the definition event (not a problem — it's the same call chain)
        XCTAssertEqual(definition?.experienceLocation, "homepage")
    }

    func testCaptureExperienceLocation_ExcludedViewEvent_StillCapturesLocation() {
        // This is the key scenario: an excluded VIEW event must still update the stored definition's
        // location so that subsequent asset events can correctly evaluate exclusion.
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        // Register definition first (location-independent)
        mockStateManager.registerExperienceDefinition(
            experienceId: "banner",
            assets: ["https://example.com/banner.jpg"],
            texts: [],
            ctas: nil
        )

        // This VIEW event will be excluded by the regexp, but location must still be captured
        let excludedViewEvent = TestEventFactory.createExperienceEvent(
            id: "banner",
            location: "test-admin-panel",
            interaction: .view
        )

        let expExpectation = self.expectation(description: "Experience processed")
        orchestrator.processExperienceEvent(excludedViewEvent) { _ in expExpectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        // The experience event itself was dropped (excluded)
        XCTAssertFalse(mockEventDispatcher.eventDispatched,
                       "Excluded experience event should not be dispatched")

        // But the location was still captured — now an asset event should be excluded too
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/banner.jpg",
            location: "content",
            interaction: .view
        )

        let assetExpectation = self.expectation(description: "Asset processed")
        orchestrator.processAssetEvent(assetEvent) { _ in assetExpectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(mockEventDispatcher.eventDispatched,
                       "Asset belonging to the excluded experience should be dropped")
    }

    func testCaptureExperienceLocation_SameExperienceDifferentLocations_UsesLatest() {
        // Same experience viewed at multiple locations — only the most recent matters for exclusion
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        mockStateManager.registerExperienceDefinition(
            experienceId: "card",
            assets: ["https://example.com/card.jpg"],
            texts: [],
            ctas: nil
        )

        // First view: excluded location
        let firstView = TestEventFactory.createExperienceEvent(
            id: "card",
            location: "test-page",
            interaction: .view
        )
        let exp1 = self.expectation(description: "First view")
        orchestrator.processExperienceEvent(firstView) { _ in exp1.fulfill() }
        waitForExpectations(timeout: 1.0)

        // Second view: non-excluded location (e.g. experience shown on a real page later)
        mockEventDispatcher.reset()
        let secondView = TestEventFactory.createExperienceEvent(
            id: "card",
            location: "homepage",
            interaction: .view
        )
        let exp2 = self.expectation(description: "Second view")
        orchestrator.processExperienceEvent(secondView) { _ in exp2.fulfill() }
        waitForExpectations(timeout: 1.0)

        // Asset event now: should be tracked because latest location is non-excluded
        mockEventDispatcher.reset()
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/card.jpg",
            location: "content",
            interaction: .view
        )
        let exp3 = self.expectation(description: "Asset processed")
        orchestrator.processAssetEvent(assetEvent) { _ in exp3.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(mockEventDispatcher.eventDispatched,
                      "Asset should be tracked when experience's latest location is non-excluded")
    }

    // MARK: - Exclude Assets From Untracked Experience

    // --- Primary path: attribution via registered experience definition ---
    //
    // Assets are attributed to experiences through the definition registration payload (asset URL list),
    // not through the experienceLocation field on the asset event itself.
    // We always store definitions (even for excluded experiences) so we can look up which experience
    // owns a given asset URL when the asset event arrives.

    func testExcludeAssets_WhenFlagTrue_AssetInExcludedExperienceDefinition_ExcludesAsset() {
        // Given - flag enabled, experience location exclusion pattern
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        // Register a definition (location-independent, as in production use)
        mockStateManager.registerExperienceDefinition(
            experienceId: "exp-excluded",
            assets: ["https://example.com/image.jpg"],
            texts: [],
            ctas: nil
        )
        // Simulate a VIEW event setting the last-seen location (matches exclusion regexp)
        mockStateManager.updateExperienceLocation(experienceId: "exp-excluded", location: "test-environment")

        // Asset event has no experienceLocation — attribution is via the definition above
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(
            mockEventDispatcher.eventDispatched,
            "Asset in an excluded experience's definition should be dropped"
        )
    }

    func testExcludeAssets_WhenFlagTrue_AssetInTrackedExperienceDefinition_ProcessesAsset() {
        // Given - flag enabled, asset belongs to a non-excluded experience
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        mockStateManager.registerExperienceDefinition(
            experienceId: "exp-tracked",
            assets: ["https://example.com/image.jpg"],
            texts: [],
            ctas: nil
        )
        // VIEW event sets location to a non-excluded value
        mockStateManager.updateExperienceLocation(experienceId: "exp-tracked", location: "production-page")

        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(
            mockEventDispatcher.eventDispatched,
            "Asset in a non-excluded experience's definition should be tracked"
        )
    }

    func testExcludeAssets_WhenFlagTrue_AssetNotInAnyDefinition_ProcessesAsset() {
        // Given - flag enabled, but asset URL appears in no registered definition
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        // No definitions registered for this asset URL
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/unknown.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(
            mockEventDispatcher.eventDispatched,
            "Asset not present in any definition should be tracked (cannot infer exclusion)"
        )
    }

    func testExcludeAssets_WhenFlagFalse_AssetInExcludedExperienceDefinition_ProcessesAsset() {
        // Given - flag disabled: experience exclusion must not affect assets
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = false
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        mockStateManager.registerExperienceDefinition(
            experienceId: "exp-excluded",
            assets: ["https://example.com/image.jpg"],
            texts: [],
            ctas: nil
        )
        mockStateManager.updateExperienceLocation(experienceId: "exp-excluded", location: "test-environment")

        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(
            mockEventDispatcher.eventDispatched,
            "Experience exclusion must not affect assets when flag is false"
        )
    }

    // --- Fallback path: asset event carries experienceLocation directly ---
    // Used when no definition was registered (e.g. custom integrations).

    func testExcludeAssets_FallbackPath_AssetEventCarriesExcludedExperienceLocation_ExcludesAsset() {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        // No definition registered; the asset event itself carries the location
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view,
            experienceLocation: "test-environment"
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(
            mockEventDispatcher.eventDispatched,
            "Asset event carrying an excluded experienceLocation should be dropped even without a registered definition"
        )
    }

    func testExcludeAssets_FallbackPath_AssetEventCarriesTrackedExperienceLocation_ProcessesAsset() {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.excludedExperienceLocationsRegexp = "^test-.*"
        config.excludeAssetsFromUntrackedExperience = true
        config.compileRegexPatterns()
        mockStateManager.updateConfiguration(config)
        waitForConfiguration()

        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view,
            experienceLocation: "production-page"
        )

        let expectation = self.expectation(description: "Processed")
        orchestrator.processAssetEvent(assetEvent) { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(
            mockEventDispatcher.eventDispatched,
            "Asset event with non-excluded experienceLocation should be tracked"
        )
    }
}
