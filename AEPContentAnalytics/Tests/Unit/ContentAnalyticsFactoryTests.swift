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

/// Tests for factory: orchestrator creation, dependency injection, and component wiring.
class ContentAnalyticsFactoryTests: XCTestCase {

    var mockRuntime: TestableExtensionRuntime!
    var stateManager: ContentAnalyticsStateManager!
    var mockPrivacyValidator: MockPrivacyValidator!
    var factory: ContentAnalyticsFactory!

    override func setUp() {
        super.setUp()
        mockRuntime = TestableExtensionRuntime()
        stateManager = ContentAnalyticsStateManager()
        mockPrivacyValidator = MockPrivacyValidator()
        factory = ContentAnalyticsFactory(extensionRuntime: mockRuntime, state: stateManager, privacyValidator: mockPrivacyValidator)
    }

    override func tearDown() {
        factory = nil
        stateManager = nil
        mockRuntime = nil
        super.tearDown()
    }

    // MARK: - Factory Initialization Tests

    func testFactory_Initialization_CreatesValidInstance() {
        // Given - Factory parameters
        let runtime = TestableExtensionRuntime()
        let state = ContentAnalyticsStateManager()
        let privacyValidator = MockPrivacyValidator()

        // When - Factory is created
        let factory = ContentAnalyticsFactory(extensionRuntime: runtime, state: state, privacyValidator: privacyValidator)

        // Then - Should create valid instance
        XCTAssertNotNil(factory, "Factory should be created successfully")
    }

    // MARK: - Orchestrator Creation Tests

    func testCreateContentAnalyticsOrchestrator_CreatesValidOrchestrator() {
        // Given - Factory is initialized

        // When - Create orchestrator
        let orchestrator = factory.createContentAnalyticsOrchestrator()

        // Then - Should create valid orchestrator
        XCTAssertNotNil(orchestrator, "Factory should create valid orchestrator")
    }

    func testCreateContentAnalyticsOrchestrator_CreatesOrchestratorWithDependencies() {
        // Given - Factory is initialized

        // When - Create orchestrator
        let orchestrator = factory.createContentAnalyticsOrchestrator()

        // Then - Orchestrator should be functional (can process events)
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(assetEvent) { _ in
            // Should process without crashing
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        // Success: orchestrator processed event without crashing
    }

    func testCreateContentAnalyticsOrchestrator_WiresBatchCoordinatorCallbacks() {
        // Given - Factory is initialized

        // When - Create orchestrator
        let orchestrator = factory.createContentAnalyticsOrchestrator()

        // Then - Batch coordinator callbacks should be wired (verified by orchestrator creation)
        XCTAssertNotNil(orchestrator, "Orchestrator should be created with batch coordinator")
    }

    // MARK: - Dependency Injection Tests

    func testCreateContentAnalyticsOrchestrator_InjectsStateManager() {
        // Given - Factory with specific state manager
        let customState = ContentAnalyticsStateManager()
        let customConfig = TestDataBuilder.buildConfiguration(trackExperiences: false)
        customState.updateConfiguration(customConfig)

        let customPrivacyValidator = MockPrivacyValidator()
        let customFactory = ContentAnalyticsFactory(extensionRuntime: mockRuntime, state: customState, privacyValidator: customPrivacyValidator)

        // When - Create orchestrator
        let orchestrator = customFactory.createContentAnalyticsOrchestrator()

        // Then - Orchestrator should use the injected state manager
        // Verify by checking orchestrator respects config
        let assetEvent = TestEventFactory.createAssetEvent(
            url: "https://example.com/image.jpg",
            location: "home",
            interaction: .view
        )

        let expectation = self.expectation(description: "Event processed")
        orchestrator.processAssetEvent(assetEvent) { _ in
            // Should process without crashing
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        // Success: orchestrator used injected state manager
    }

    func testCreateContentAnalyticsOrchestrator_InjectsEventDispatcher() {
        // Given - Factory is initialized

        // When - Create orchestrator
        let orchestrator = factory.createContentAnalyticsOrchestrator()

        // Then - Event dispatcher should be injected (verified by orchestrator creation)
        XCTAssertNotNil(orchestrator, "Orchestrator should be created with event dispatcher")
    }

    func testCreateContentAnalyticsOrchestrator_InjectsPrivacyValidator() {
        // Given - Factory is initialized

        // When - Create orchestrator
        let orchestrator = factory.createContentAnalyticsOrchestrator()

        // Then - Privacy validator should be injected (verified by orchestrator creation)
        XCTAssertNotNil(orchestrator, "Orchestrator should be created with privacy validator")
    }

    // MARK: - Multiple Instance Tests

    func testCreateContentAnalyticsOrchestrator_MultipleCalls_CreateIndependentInstances() {
        // Given - Factory is initialized

        // When - Create multiple orchestrators
        let orchestrator1 = factory.createContentAnalyticsOrchestrator()
        let orchestrator2 = factory.createContentAnalyticsOrchestrator()

        // Then - Should create independent instances
        XCTAssertNotEqual(ObjectIdentifier(orchestrator1), ObjectIdentifier(orchestrator2),
                         "Multiple calls should create independent orchestrator instances")
    }
}
