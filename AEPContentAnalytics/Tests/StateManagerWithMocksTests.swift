/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPContentAnalytics
import AEPServices
import XCTest

/// Demonstrates the power of protocol-based dependency injection.
/// All dependencies are mocked - NO disk I/O, NO real implementations.
/// Tests are fast, isolated, and focused on StateManager logic only.
class StateManagerWithMocksTests: XCTestCase {
    
    var stateManager: ContentAnalyticsStateManager!
    var mockCache: MockDefinitionCache!
    var mockConfig: MockConfigurationManager!
    
    override func setUp() {
        super.setUp()
        
        // Create mocks
        mockCache = MockDefinitionCache()
        mockConfig = MockConfigurationManager()
        
        // Inject mocks into StateManager
        stateManager = ContentAnalyticsStateManager(
            configManager: mockConfig,
            definitionCache: mockCache
        )
    }
    
    override func tearDown() {
        stateManager = nil
        mockCache = nil
        mockConfig = nil
        super.tearDown()
    }
    
    // MARK: - Store Definition Tests
    
    func testStoreExperienceDefinition_StoresInCache() {
        // When
        stateManager.registerExperienceDefinition(
            experienceId: "exp1",
            assets: ["https://example.com/image.jpg"],
            texts: [ContentItem(value: "Test")],
            ctas: nil
        )
        
        // Then - should store in cache
        XCTAssertEqual(mockCache.storedDefinitions.count, 1)
        XCTAssertEqual(mockCache.storedDefinitions.first?.experienceId, "exp1")
    }
    
    // MARK: - Get Definition Tests
    
    func testGetExperienceDefinition_CacheHit_ReturnsFromCache() {
        // Given - definition in cache
        let definition = createDefinition(id: "exp1")
        mockCache.definitions["exp1"] = definition
        
        // When
        let result = stateManager.getExperienceDefinition(for: "exp1")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.experienceId, "exp1")
        XCTAssertEqual(mockCache.getCallCount, 1)
    }
    
    func testGetExperienceDefinition_NotFound_ReturnsNil() {
        // Given - definition doesn't exist
        
        // When
        let result = stateManager.getExperienceDefinition(for: "nonexistent")
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - Featurization Tests
    
    func testMarkExperienceDefinitionAsSent_UpdatesCache() {
        // Given - definition exists
        let definition = createDefinition(id: "exp1", sentToFeaturization: false)
        mockCache.definitions["exp1"] = definition
        
        // When
        stateManager.markExperienceDefinitionAsSent(experienceId: "exp1")
        
        // Then
        XCTAssertEqual(mockCache.updateCallCount, 1)
        
        let updated = mockCache.definitions["exp1"]
        XCTAssertTrue(updated?.sentToFeaturization == true)
    }
    
    func testHasExperienceDefinitionBeenSent_ReturnsTrue() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: true)
        mockCache.definitions["exp1"] = definition
        
        // When
        let result = stateManager.hasExperienceDefinitionBeenSent(for: "exp1")
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testHasExperienceDefinitionBeenSent_ReturnsFalse() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: false)
        mockCache.definitions["exp1"] = definition
        
        // When
        let result = stateManager.hasExperienceDefinitionBeenSent(for: "exp1")
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Configuration Tests
    
    func testBatchingEnabled_DelegatesToConfigManager() {
        // Given
        mockConfig.batchingEnabledValue = true
        
        // When
        let result = stateManager.batchingEnabled
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockConfig.batchingEnabledCallCount, 1)
    }
    
    func testShouldTrackUrl_DelegatesToConfigManager() {
        // Given
        let url = URL(string: "https://example.com")!
        mockConfig.urlTrackingResult = true
        
        // When
        let result = stateManager.shouldTrackUrl(url)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockConfig.shouldTrackUrlCallCount, 1)
    }
    
    // MARK: - Reset Tests
    
    func testReset_ClearsAllComponents() {
        // When
        stateManager.reset()
        
        // Allow async reset to complete
        let expectation = XCTestExpectation(description: "Reset completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(mockConfig.resetCallCount, 1)
        XCTAssertEqual(mockCache.removeAllCallCount, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createDefinition(id: String, sentToFeaturization: Bool = false) -> ExperienceDefinition {
        return ExperienceDefinition(
            experienceId: id,
            assets: ["https://example.com/\(id).jpg"],
            texts: [ContentItem(value: "Title \(id)")],
            ctas: nil,
            sentToFeaturization: sentToFeaturization
        )
    }
}

// MARK: - Mock Implementations

/// Mock cache that tracks all calls and stores definitions in memory
class MockDefinitionCache: DefinitionCacheProtocol {
    var definitions: [String: ExperienceDefinition] = [:]
    var storedDefinitions: [ExperienceDefinition] = []
    
    var getCallCount = 0
    var storeCallCount = 0
    var updateCallCount = 0
    var removeAllCallCount = 0
    
    func store(_ definition: ExperienceDefinition) {
        storeCallCount += 1
        storedDefinitions.append(definition)
        definitions[definition.experienceId] = definition
    }
    
    func get(experienceId: String) -> ExperienceDefinition? {
        getCallCount += 1
        return definitions[experienceId]
    }
    
    func contains(experienceId: String) -> Bool {
        return definitions[experienceId] != nil
    }
    
    func update(_ definition: ExperienceDefinition) {
        updateCallCount += 1
        definitions[definition.experienceId] = definition
    }
    
    func getAllDefinitions() -> [ExperienceDefinition] {
        return Array(definitions.values)
    }
    
    var count: Int {
        return definitions.count
    }
    
    func markAsSent(experienceId: String) -> ExperienceDefinition? {
        guard var definition = definitions[experienceId] else { return nil }
        definition.sentToFeaturization = true
        definitions[experienceId] = definition
        return definition
    }
    
    func hasBeenSent(experienceId: String) -> Bool {
        return definitions[experienceId]?.sentToFeaturization ?? false
    }
    
    func getSentCount() -> Int {
        return definitions.values.filter { $0.sentToFeaturization }.count
    }
    
    func removeAll() {
        removeAllCallCount += 1
        definitions.removeAll()
        storedDefinitions.removeAll()
    }
}

/// Mock configuration manager that tracks all calls
class MockConfigurationManager: ConfigurationManaging {
    var config: ContentAnalyticsConfiguration?
    var batchingEnabledValue = false
    var urlTrackingResult = true
    var experienceTrackingResult = true
    var assetTrackingResult = true
    
    var batchingEnabledCallCount = 0
    var shouldTrackUrlCallCount = 0
    var shouldTrackExperienceCallCount = 0
    var shouldTrackAssetLocationCallCount = 0
    var resetCallCount = 0
    
    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        self.config = config
    }
    
    func getCurrentConfiguration() -> ContentAnalyticsConfiguration? {
        return config
    }
    
    var batchingEnabled: Bool {
        batchingEnabledCallCount += 1
        return batchingEnabledValue
    }
    
    func shouldTrackUrl(_ url: URL) -> Bool {
        shouldTrackUrlCallCount += 1
        return urlTrackingResult
    }
    
    func shouldTrackExperience(location: String?) -> Bool {
        shouldTrackExperienceCallCount += 1
        return experienceTrackingResult
    }
    
    func shouldTrackAssetLocation(_ location: String?) -> Bool {
        shouldTrackAssetLocationCallCount += 1
        return assetTrackingResult
    }
    
    func reset() {
        resetCallCount += 1
        config = nil
    }
}
