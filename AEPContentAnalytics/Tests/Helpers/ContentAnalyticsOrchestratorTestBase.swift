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

/// Base class for orchestrator unit tests with common setup/teardown
///
/// **What this provides:**
/// - Pre-configured mocks (state manager, batch coordinator, dispatcher, privacy validator, XDM builder)
/// - Permissive default configuration (allows all tracking)
/// - Clean teardown
/// - Reusable across all orchestrator test files
///
/// **Usage:**
/// ```swift
/// final class MyOrchestratorTests: ContentAnalyticsOrchestratorTestBase {
///     func testSomething() {
///         // All mocks are ready to use:
///         // - orchestrator
///         // - mockStateManager
///         // - mockBatchCoordinator
///         // - mockEventDispatcher
///         // - mockPrivacyValidator
///         // - mockXDMBuilder
///     }
/// }
/// ```
class ContentAnalyticsOrchestratorTestBase: XCTestCase {

    // MARK: - Test Properties (Available in Subclasses)

    var mockStateManager: ContentAnalyticsStateManager!
    var mockBatchCoordinator: MockBatchCoordinator!
    var mockEventDispatcher: OrchestratorMockEventDispatcher!
    var mockPrivacyValidator: MockPrivacyValidator!
    var mockXDMBuilder: OrchestratorMockXDMEventBuilder!
    var orchestrator: ContentAnalyticsOrchestrator!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create all mocks
        mockStateManager = ContentAnalyticsStateManager()
        mockBatchCoordinator = MockBatchCoordinator()
        mockEventDispatcher = OrchestratorMockEventDispatcher()
        mockPrivacyValidator = MockPrivacyValidator()
        mockXDMBuilder = OrchestratorMockXDMEventBuilder()

        // Configure state manager with permissive configuration (allows all tracking)
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false // Default to immediate dispatch for faster tests
        config.trackExperiences = true
        config.excludedAssetLocationsRegexp = nil
        config.excludedAssetUrlsRegexp = nil
        config.excludedExperienceLocationsRegexp = nil
        mockStateManager.updateConfiguration(config)

        // IMPORTANT: Wait for async configuration update to complete
        // StateManager.updateConfiguration() uses async dispatch, so we need to ensure
        // the configuration is actually set before tests run. This prevents race conditions
        // where tests try to process events before configuration is available.
        waitForConfiguration()

        // Privacy validator allows tracking by default
        mockPrivacyValidator.shouldTrack = true

        // Create orchestrator with mocked dependencies
        orchestrator = ContentAnalyticsOrchestrator(
            state: mockStateManager,
            eventDispatcher: mockEventDispatcher,
            privacyValidator: mockPrivacyValidator,
            xdmEventBuilder: mockXDMBuilder,
            featurizationHitQueue: nil,
            batchCoordinator: mockBatchCoordinator
        )
    }

    override func tearDown() {
        // Reset mocks
        mockBatchCoordinator.reset()
        mockPrivacyValidator.reset()
        mockEventDispatcher.reset()

        // Cleanup
        orchestrator = nil
        mockXDMBuilder = nil
        mockPrivacyValidator = nil
        mockEventDispatcher = nil
        mockBatchCoordinator = nil
        mockStateManager = nil

        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Updates configuration with batching enabled
    func enableBatching(maxBatchSize: Int = 10, flushInterval: TimeInterval = 5.0) {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = true
        config.maxBatchSize = maxBatchSize
        config.batchFlushInterval = flushInterval
        config.trackExperiences = true
        config.excludedAssetLocationsRegexp = nil
        config.excludedAssetUrlsRegexp = nil
        config.excludedExperienceLocationsRegexp = nil
        mockStateManager.updateConfiguration(config)
        waitForConfiguration() // Ensure config is set before returning
    }

    /// Updates configuration with batching disabled
    func disableBatching() {
        var config = ContentAnalyticsConfiguration()
        config.batchingEnabled = false
        config.trackExperiences = true
        config.excludedAssetLocationsRegexp = nil
        config.excludedAssetUrlsRegexp = nil
        config.excludedExperienceLocationsRegexp = nil
        mockStateManager.updateConfiguration(config)
        waitForConfiguration() // Ensure config is set before returning
    }

    /// Blocks tracking via privacy validator
    func blockTracking() {
        mockPrivacyValidator.shouldTrack = false
    }

    /// Allows tracking via privacy validator
    func allowTracking() {
        mockPrivacyValidator.shouldTrack = true
    }

    // MARK: - Private Helpers

    /// Waits for async configuration update to complete
    /// This prevents race conditions where configuration isn't set yet when tests run
    private func waitForConfiguration() {
        // Poll until configuration is set (with timeout)
        let startTime = Date()
        let timeout: TimeInterval = 1.0

        while mockStateManager.getCurrentConfiguration() == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                XCTFail("Configuration not set after \(timeout)s timeout")
                break
            }
            // Small sleep to avoid busy-waiting
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
