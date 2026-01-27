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

import Foundation
import AEPCore
import AEPServices
@testable import AEPContentAnalytics

// MARK: - CENTRALIZED TEST MOCKS
//
// This file contains protocol-based and lightweight mocks for general testing.
//
// ARCHITECTURE:
// 1. TestableExtensionRuntime: Use from TestHelpers/TestableExtensionRuntime.swift
// 2. Protocol mocks (this file): Lightweight implementations of protocols
// 3. Subclass mocks (test files): When tests need to override specific behavior,
//    they define local mocks with unique prefixes (e.g., OrchestratorMock*, FeaturizationMock*)
//
// This avoids duplication while allowing flexibility for specific test needs.

// MARK: - Mock State Manager

class MockStateManager {
    var isEnabled = true
    var batchingEnabled = true
    var trackingEnabled = true
    var privacyStatus: PrivacyStatus = .optedIn
    var sentExperienceDefinitions = Set<String>()
    var trackedMetrics: [String: Any] = [:]
    var mockConfiguration: ContentAnalyticsConfiguration?
    var mockAssetMetrics: [String: [String: Any]] = [:]
    var mockExperienceMetrics: [String: [String: Any]] = [:]
    
    // Track method calls
    var trackEngagementMetricsCalled = false
    var trackExperienceEngagementMetricsCalled = false
    var markDefinitionSentCalled = false
    
    func reset() {
        isEnabled = true
        batchingEnabled = true
        trackingEnabled = true
        privacyStatus = .optedIn
        sentExperienceDefinitions.removeAll()
        trackedMetrics.removeAll()
        mockAssetMetrics.removeAll()
        mockExperienceMetrics.removeAll()
        trackEngagementMetricsCalled = false
        trackExperienceEngagementMetricsCalled = false
        markDefinitionSentCalled = false
    }
}

// MARK: - Mock Batch Coordinator

/// Enhanced mock batch coordinator that conforms to BatchCoordinating protocol
/// Tracks all operations for verification in unit tests
class MockBatchCoordinator: BatchCoordinating {
    var assetEvents: [Event] = []
    var experienceEvents: [Event] = []
    var flushCalled = false
    var flushCallCount = 0
    var clearCalled = false
    var updateConfigurationCalled = false
    var configuration: BatchingConfiguration?
    
    func addAssetEvent(_ event: Event) {
        assetEvents.append(event)
    }
    
    func addExperienceEvent(_ event: Event) {
        experienceEvents.append(event)
    }
    
    func flush() {
        flushCalled = true
        flushCallCount += 1
    }
    
    func clear() {
        clearCalled = true
        assetEvents.removeAll()
        experienceEvents.removeAll()
    }
    
    func updateConfiguration(_ config: BatchingConfiguration) {
        updateConfigurationCalled = true
        configuration = config
    }
    
    func reset() {
        assetEvents.removeAll()
        experienceEvents.removeAll()
        flushCalled = false
        flushCallCount = 0
        clearCalled = false
        updateConfigurationCalled = false
        configuration = nil
    }
}

// MARK: - Mock Event Dispatcher

class MockEventDispatcher {
    var dispatchedEvents: [Event] = []
    var dispatchCount = 0
    
    func dispatch(event: Event) {
        dispatchedEvents.append(event)
        dispatchCount += 1
    }
    
    func reset() {
        dispatchedEvents.removeAll()
        dispatchCount = 0
    }
}

// NOTE: MockXDMEventBuilder removed - tests use specific mocks (OrchestratorMock*, PersistentBatchMock*)

// MARK: - Mock Network Service

class MockNetworkService: Networking {
    var mockResponseData: (data: Data?, response: HTTPURLResponse?, error: Error?)?
    var lastRequest: NetworkRequest?
    
    func connectAsync(networkRequest: NetworkRequest, completionHandler: ((HttpConnection) -> Void)?) {
        lastRequest = networkRequest
        // HttpConnection is a struct - create it directly
        let connection = HttpConnection(
            data: mockResponseData?.data,
            response: mockResponseData?.response,
            error: mockResponseData?.error
        )
        completionHandler?(connection)
    }
    
    /// Check if a request was made to a specific URL
    func requestMade(to url: String) -> Bool {
        return lastRequest?.url.absoluteString == url
    }
    
    /// Convenience method for setting up mock responses with data
    func mockResponse(url: String, statusCode: Int, data: Data?) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        mockResponseData = (data: data, response: response, error: nil)
    }
    
    /// Convenience method for setting up mock responses with error
    func mockResponse(url: String, statusCode: Int? = nil, error: Error) {
        let response: HTTPURLResponse?
        if let code = statusCode {
            response = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )
        } else {
            response = nil
        }
        mockResponseData = (data: nil, response: response, error: error)
    }
    
    /// Convenience method for setting up mock errors
    func mockError(url: String, error: Error) {
        mockResponseData = (data: nil, response: nil, error: error)
    }
    
    func reset() {
        mockResponseData = nil
        lastRequest = nil
    }
}

// MARK: - Mock Privacy Validator

class MockPrivacyValidator: PrivacyValidator {
    var shouldTrack = true
    var isDataCollectionAllowedCallCount = 0
    
    func isDataCollectionAllowed() -> Bool {
        isDataCollectionAllowedCallCount += 1
        return shouldTrack
    }
    
    func reset() {
        shouldTrack = true
        isDataCollectionAllowedCallCount = 0
    }
}

// NOTE: MockMetricsManager removed - protocol conformance issues

// NOTE: MockDataQueue removed - protocol conformance issues

// MARK: - Mock Featurization Service

class MockFeaturizationService: ExperienceFeaturizationServiceProtocol {
    var checkExistsCalled = false
    var registerExperienceCalled = false
    var mockExistsResult: Result<Bool, Error> = .success(false)
    var mockRegisterResult: Result<Void, Error> = .success(())
    
    func checkExperienceExists(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        checkExistsCalled = true
        completion(mockExistsResult)
    }
    
    func registerExperience(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        content: ExperienceContent,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        registerExperienceCalled = true
        completion(mockRegisterResult)
    }
    
    func reset() {
        checkExistsCalled = false
        registerExperienceCalled = false
        mockExistsResult = .success(false)
        mockRegisterResult = .success(())
    }
}

// MARK: - Test Error Types

enum TestError: Error {
    case mockNetworkError
    case mockHTTPError(Int)
    case mockValidationError
}

// NOTE: Subclass-based mocks removed due to protocol conformance issues
// Tests that need specific behavior use the existing protocol-based mocks below


class MockEdgeEventDispatcher: ContentAnalyticsEventDispatcher {
    var onDispatch: ((Event) -> Void)?
    
    func dispatch(event: Event) {
        onDispatch?(event)
    }
}

class PersistentBatchMockPrivacyValidator {
    var shouldAllowEvent = true
    
    func isEventAllowed(_ event: Event) -> Bool {
        return shouldAllowEvent
    }
}

// NOTE: PersistentBatchMockXDMEventBuilder removed - protocol conformance issues

// NOTE: FeaturizationMockNetworkService and FeaturizationMockHttpConnection removed - protocol conformance issues
// Tests needing network mocking should use MockNetworkService above

// NOTE: HitProcessorMockFeaturizationService removed - use MockFeaturizationService above instead

// MARK: - Additional Test Mocks (Simple standalone versions)
// MockMetricsRepository removed - metrics now calculated from events

class HitProcessorMockFeaturizationService: ExperienceFeaturizationServiceProtocol {
    var checkResponses: [String: Result<Bool, Error>] = [:]
    var registerResponses: [String: Result<Void, Error>] = [:]
    var registrationCallCount: [String: Int] = [:]
    
    func checkExperienceExists(experienceId: String, imsOrg: String, datastreamId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        if let response = checkResponses[experienceId] {
            completion(response)
        } else {
            completion(.success(false))
        }
    }
    
    func registerExperience(experienceId: String, imsOrg: String, datastreamId: String, content: ExperienceContent, completion: @escaping (Result<Void, Error>) -> Void) {
        registrationCallCount[experienceId, default: 0] += 1
        if let response = registerResponses[experienceId] {
            completion(response)
        } else {
            completion(.success(()))
        }
    }
    
    func mockCheckResponse(experienceId: String, exists: Bool) {
        checkResponses[experienceId] = .success(exists)
    }
    
    func mockCheckError(experienceId: String, error: Error) {
        checkResponses[experienceId] = .failure(error)
    }
    
    func mockRegisterSuccess(experienceId: String) {
        registerResponses[experienceId] = .success(())
    }
    
    func mockRegisterError(experienceId: String, error: Error) {
        registerResponses[experienceId] = .failure(error)
    }
    
    func registrationCalled(for experienceId: String) -> Bool {
        return (registrationCallCount[experienceId] ?? 0) > 0
    }
    
    func reset() {
        checkResponses.removeAll()
        registerResponses.removeAll()
        registrationCallCount.removeAll()
    }
}

// FeaturizationMockNetworkService and FeaturizationMockHttpConnection removed
// These mocks are only used by disabled test files (ExperienceFeaturizationServiceTests.swift.disabled)
// If you need to re-enable those tests, these mocks will need to be rewritten to properly conform to HttpConnection protocol

class OrchestratorMockStateManager {
    var isEnabled = true
    var hasDefinitionBeenSent = false
    var definitionMarkedSent = false
    var metricsTracked = false
    var mockAssetMetrics: [String: [String: Any]] = [:]
    var mockExperienceMetrics: [String: [String: Any]] = [:]
}

class OrchestratorMockBatchCoordinator {
    var assetEventAdded = false
    var experienceEventAdded = false
    var flushCalled = false
    
    func addAssetEvent(_ event: Event) {
        assetEventAdded = true
    }
    
    func addExperienceEvent(_ event: Event) {
        experienceEventAdded = true
    }
    
    func flush() {
        flushCalled = true
    }
}

class OrchestratorMockEventDispatcher: ContentAnalyticsEventDispatcher {
    var eventDispatched = false
    var dispatchedEvents: [Event] = []
    
    func dispatch(event: Event) {
        eventDispatched = true
        dispatchedEvents.append(event)
    }
    
    func reset() {
        eventDispatched = false
        dispatchedEvents.removeAll()
    }
}

class OrchestratorMockXDMEventBuilder: XDMEventBuilderProtocol {
    var createAssetXDMEventCalled = false
    var createAssetXDMEventCallCount = 0
    var createExperienceDefinitionEventCalled = false
    var createExperienceXDMEventCalled = false
    
    // AssetXDMBuilder protocol
    func createAssetXDMEvent(from assetKeys: [String], metrics: [String: [String: Any]], triggeringInteractionType: InteractionType) -> [String: Any] {
        createAssetXDMEventCalled = true
        createAssetXDMEventCallCount += 1
        return ["test": "xdm", "assetKeys": assetKeys.count]
    }
    
    // ExperienceXDMBuilder protocol - Definition
    func createExperienceDefinitionEvent(experienceId: String, assetURLs: [String], textContent: [ContentItem], buttonContent: [ContentItem]?, experienceLocation: String) -> [String: Any] {
        createExperienceDefinitionEventCalled = true
        return ["test": "definition"]
    }
    
    // ExperienceXDMBuilder protocol - Interaction
    func createExperienceXDMEvent(experienceId: String, interactionType: InteractionType, metrics: [String: Any], assetURLs: [String], experienceLocation: String?, state: ContentAnalyticsStateManager) -> [String: Any] {
        createExperienceXDMEventCalled = true
        return ["test": "interaction"]
    }
}

// MARK: - Orchestrator Test Mocks

class MockContentAnalyticsStateManager: ContentAnalyticsStateManager {
    var shouldTrackUrlResult = true
    var shouldExcludeExperienceResult = false
    
    override func shouldTrackUrl(_ url: URL) -> Bool {
        return shouldTrackUrlResult
    }
}

class MockContentAnalyticsEventDispatcher: ContentAnalyticsEventDispatcher {
    
    var dispatchCalled = false
    var dispatchedEvents: [Event] = []
    
    func dispatch(event: Event) {
        dispatchCalled = true
        dispatchedEvents.append(event)
    }
}

class MockXDMEventBuilder: XDMEventBuilderProtocol {
    
    var createXDMEventCalled = false
    var createExperienceXDMEventCalled = false
    
    // AssetXDMBuilder protocol
    func createAssetXDMEvent(from assetKeys: [String], metrics: [String: [String: Any]], triggeringInteractionType: InteractionType) -> [String: Any] {
        createXDMEventCalled = true
        return ["test": "asset-xdm", "assetKeys": assetKeys.count]
    }
    
    // ExperienceXDMBuilder protocol
    func createExperienceXDMEvent(
        experienceId: String,
        interactionType: InteractionType,
        metrics: [String: Any],
        assetURLs: [String],
        experienceLocation: String?,
        state: ContentAnalyticsStateManager
    ) -> [String: Any] {
        createExperienceXDMEventCalled = true
        return ["test": "experience-interaction-xdm", "experienceId": experienceId]
    }
}
