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
import XCTest

class DefinitionCacheTests: XCTestCase {
    
    var cache: DefinitionCache!
    
    override func setUp() {
        super.setUp()
        cache = DefinitionCache(capacity: 3) // Small capacity for testing
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    // MARK: - Store and Retrieve Tests
    
    func testStore_AndRetrieve_Success() {
        // Given
        let definition = createDefinition(id: "exp1")
        
        // When
        cache.store(definition)
        
        // Then
        let retrieved = cache.get(experienceId: "exp1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.experienceId, "exp1")
    }
    
    func testGet_NonExistent_ReturnsNil() {
        // When/Then
        XCTAssertNil(cache.get(experienceId: "nonexistent"))
    }
    
    func testContains_ExistingDefinition_ReturnsTrue() {
        // Given
        let definition = createDefinition(id: "exp1")
        cache.store(definition)
        
        // When/Then
        XCTAssertTrue(cache.contains(experienceId: "exp1"))
    }
    
    func testContains_NonExistent_ReturnsFalse() {
        // When/Then
        XCTAssertFalse(cache.contains(experienceId: "nonexistent"))
    }
    
    // MARK: - Update Tests
    
    func testUpdate_ExistingDefinition_Success() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: false)
        cache.store(definition)
        
        // When
        var updated = definition
        updated.sentToFeaturization = true
        cache.update(updated)
        
        // Then
        let retrieved = cache.get(experienceId: "exp1")
        XCTAssertTrue(retrieved?.sentToFeaturization == true)
    }
    
    // MARK: - LRU Eviction Tests
    
    func testLRUEviction_WhenCapacityExceeded() {
        // Given - cache capacity is 3
        cache.store(createDefinition(id: "exp1"))
        cache.store(createDefinition(id: "exp2"))
        cache.store(createDefinition(id: "exp3"))
        
        // When - add 4th definition
        cache.store(createDefinition(id: "exp4"))
        
        // Then - exp1 should be evicted
        XCTAssertNil(cache.get(experienceId: "exp1"))
        XCTAssertNotNil(cache.get(experienceId: "exp2"))
        XCTAssertNotNil(cache.get(experienceId: "exp3"))
        XCTAssertNotNil(cache.get(experienceId: "exp4"))
    }
    
    func testLRUEviction_AccessUpdatesRecency() {
        // Given - cache capacity is 3
        cache.store(createDefinition(id: "exp1"))
        cache.store(createDefinition(id: "exp2"))
        cache.store(createDefinition(id: "exp3"))
        
        // When - access exp1 (making it most recent)
        _ = cache.get(experienceId: "exp1")
        
        // Then add exp4, exp2 should be evicted (least recent)
        cache.store(createDefinition(id: "exp4"))
        
        XCTAssertNotNil(cache.get(experienceId: "exp1")) // Still present
        XCTAssertNil(cache.get(experienceId: "exp2")) // Evicted
        XCTAssertNotNil(cache.get(experienceId: "exp3"))
        XCTAssertNotNil(cache.get(experienceId: "exp4"))
    }
    
    // MARK: - Featurization Tracking Tests
    
    func testMarkAsSent_ExistingDefinition_Success() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: false)
        cache.store(definition)
        
        // When
        let updated = cache.markAsSent(experienceId: "exp1")
        
        // Then
        XCTAssertNotNil(updated)
        XCTAssertTrue(updated?.sentToFeaturization == true)
        XCTAssertTrue(cache.hasBeenSent(experienceId: "exp1"))
    }
    
    func testMarkAsSent_NonExistent_ReturnsNil() {
        // When/Then
        XCTAssertNil(cache.markAsSent(experienceId: "nonexistent"))
    }
    
    func testHasBeenSent_WhenSent_ReturnsTrue() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: true)
        cache.store(definition)
        
        // When/Then
        XCTAssertTrue(cache.hasBeenSent(experienceId: "exp1"))
    }
    
    func testHasBeenSent_WhenNotSent_ReturnsFalse() {
        // Given
        let definition = createDefinition(id: "exp1", sentToFeaturization: false)
        cache.store(definition)
        
        // When/Then
        XCTAssertFalse(cache.hasBeenSent(experienceId: "exp1"))
    }
    
    func testGetSentCount_ReturnsCorrectCount() {
        // Given
        cache.store(createDefinition(id: "exp1", sentToFeaturization: true))
        cache.store(createDefinition(id: "exp2", sentToFeaturization: false))
        cache.store(createDefinition(id: "exp3", sentToFeaturization: true))
        
        // When/Then
        XCTAssertEqual(cache.getSentCount(), 2)
    }
    
    // MARK: - Collection Tests
    
    func testGetAllDefinitions_ReturnsAll() {
        // Given
        cache.store(createDefinition(id: "exp1"))
        cache.store(createDefinition(id: "exp2"))
        cache.store(createDefinition(id: "exp3"))
        
        // When
        let all = cache.getAllDefinitions()
        
        // Then
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains { $0.experienceId == "exp1" })
        XCTAssertTrue(all.contains { $0.experienceId == "exp2" })
        XCTAssertTrue(all.contains { $0.experienceId == "exp3" })
    }
    
    func testCount_ReturnsCorrectCount() {
        // Given
        XCTAssertEqual(cache.count, 0)
        
        cache.store(createDefinition(id: "exp1"))
        XCTAssertEqual(cache.count, 1)
        
        cache.store(createDefinition(id: "exp2"))
        XCTAssertEqual(cache.count, 2)
    }
    
    func testRemoveAll_ClearsCache() {
        // Given
        cache.store(createDefinition(id: "exp1"))
        cache.store(createDefinition(id: "exp2"))
        XCTAssertEqual(cache.count, 2)
        
        // When
        cache.removeAll()
        
        // Then
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get(experienceId: "exp1"))
        XCTAssertNil(cache.get(experienceId: "exp2"))
    }
    
    // MARK: - Helper Methods
    
    private func createDefinition(id: String, sentToFeaturization: Bool = false) -> ExperienceDefinition {
        return ExperienceDefinition(
            experienceId: id,
            assets: ["https://example.com/\(id).jpg"],
            texts: [ContentItem(location: "title", text: "Title \(id)")],
            ctas: nil,
            sentToFeaturization: sentToFeaturization
        )
    }
}
