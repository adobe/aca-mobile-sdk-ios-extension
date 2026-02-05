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
import AEPCore
import XCTest

/// Tests for MetricsBuilder - aggregates metrics from batched events
final class MetricsBuilderTests: XCTestCase {
    
    var stateManager: ContentAnalyticsStateManager!
    var metricsBuilder: MetricsBuilder!
    
    override func setUp() {
        super.setUp()
        stateManager = ContentAnalyticsStateManager()
        metricsBuilder = MetricsBuilder(state: stateManager)
        
        // Apply configuration
        var config = ContentAnalyticsConfiguration()
        config.trackExperiences = true
        stateManager.updateConfiguration(config)
        waitForConfiguration()
    }
    
    override func tearDown() {
        metricsBuilder = nil
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Asset Metrics Tests
    
    func testBuildAssetMetrics_withSingleViewEvent_returnsCorrectCounts() {
        let events = [
            createAssetEvent(
                assetURL: "https://example.com/image.jpg",
                assetLocation: "header",
                action: InteractionType.view
            )
        ]
        
        let (collection, interactionType) = metricsBuilder.buildAssetMetrics(from: events)
        
        XCTAssertFalse(collection.isEmpty, "Collection should not be empty")
        XCTAssertEqual(interactionType, InteractionType.view, "Triggering interaction should be view")
        
        // Get metrics for the asset key
        for assetKey in collection.assetKeys {
            guard let metrics = collection.metrics(for: assetKey) else {
                XCTFail("Should have metrics for asset key")
                return
            }
            
            XCTAssertEqual(metrics.viewCount, 1.0, "View count should be 1")
            XCTAssertEqual(metrics.clickCount, 0.0, "Click count should be 0")
            XCTAssertEqual(metrics.assetURL, "https://example.com/image.jpg")
        }
    }
    
    func testBuildAssetMetrics_withMultipleEvents_aggregatesCounts() {
        let events = [
            createAssetEvent(
                assetURL: "https://example.com/image.jpg",
                assetLocation: "header",
                action: InteractionType.view
            ),
            createAssetEvent(
                assetURL: "https://example.com/image.jpg",
                assetLocation: "header",
                action: InteractionType.view
            ),
            createAssetEvent(
                assetURL: "https://example.com/image.jpg",
                assetLocation: "header",
                action: InteractionType.click
            )
        ]
        
        let (collection, interactionType) = metricsBuilder.buildAssetMetrics(from: events)
        
        XCTAssertEqual(collection.count, 1, "Should have 1 unique asset")
        XCTAssertEqual(interactionType, InteractionType.view, "Triggering interaction should be view (first action)")
        
        for assetKey in collection.assetKeys {
            guard let metrics = collection.metrics(for: assetKey) else {
                XCTFail("Should have metrics for asset key")
                return
            }
            
            XCTAssertEqual(metrics.viewCount, 2.0, "View count should be 2")
            XCTAssertEqual(metrics.clickCount, 1.0, "Click count should be 1")
        }
    }
    
    func testBuildAssetMetrics_withMultipleAssets_createsMultipleEntries() {
        let events = [
            createAssetEvent(
                assetURL: "https://example.com/image1.jpg",
                assetLocation: "header",
                action: InteractionType.view
            ),
            createAssetEvent(
                assetURL: "https://example.com/image2.jpg",
                assetLocation: "footer",
                action: InteractionType.view
            )
        ]
        
        let (collection, _) = metricsBuilder.buildAssetMetrics(from: events)
        
        XCTAssertEqual(collection.count, 2, "Should have 2 unique assets")
    }
    
    func testBuildAssetMetrics_withEmptyEvents_returnsEmptyCollection() {
        let events: [Event] = []
        
        let (collection, _) = metricsBuilder.buildAssetMetrics(from: events)
        
        XCTAssertTrue(collection.isEmpty, "Collection should be empty")
    }
    
    // MARK: - Experience Metrics Tests
    
    func testBuildExperienceMetrics_withSingleViewEvent_returnsCorrectCounts() {
        let events = [
            createExperienceEvent(
                experienceId: "exp-123",
                experienceLocation: "home-page",
                action: InteractionType.view
            )
        ]
        
        let (collection, interactionType) = metricsBuilder.buildExperienceMetrics(from: events)
        
        XCTAssertFalse(collection.isEmpty, "Collection should not be empty")
        XCTAssertEqual(interactionType, InteractionType.view, "Triggering interaction should be view")
        
        for experienceKey in collection.experienceKeys {
            guard let metrics = collection.metrics(for: experienceKey) else {
                XCTFail("Should have metrics for experience key")
                return
            }
            
            XCTAssertEqual(metrics.viewCount, 1.0, "View count should be 1")
            XCTAssertEqual(metrics.clickCount, 0.0, "Click count should be 0")
            XCTAssertEqual(metrics.experienceID, "exp-123")
        }
    }
    
    func testBuildExperienceMetrics_withMultipleEvents_aggregatesCounts() {
        let events = [
            createExperienceEvent(
                experienceId: "exp-123",
                experienceLocation: "home-page",
                action: InteractionType.view
            ),
            createExperienceEvent(
                experienceId: "exp-123",
                experienceLocation: "home-page",
                action: InteractionType.view
            ),
            createExperienceEvent(
                experienceId: "exp-123",
                experienceLocation: "home-page",
                action: InteractionType.click
            )
        ]
        
        let (collection, _) = metricsBuilder.buildExperienceMetrics(from: events)
        
        XCTAssertEqual(collection.count, 1, "Should have 1 unique experience")
        
        for experienceKey in collection.experienceKeys {
            guard let metrics = collection.metrics(for: experienceKey) else {
                XCTFail("Should have metrics for experience key")
                return
            }
            
            XCTAssertEqual(metrics.viewCount, 2.0, "View count should be 2")
            XCTAssertEqual(metrics.clickCount, 1.0, "Click count should be 1")
        }
    }
    
    func testBuildExperienceMetrics_withRegisteredDefinition_includesAttributedAssets() {
        // Register an experience definition
        stateManager.registerExperienceDefinition(
            experienceId: "exp-123",
            assets: ["https://example.com/asset1.jpg", "https://example.com/asset2.jpg"],
            texts: [],
            ctas: []
        )
        
        let events = [
            createExperienceEvent(
                experienceId: "exp-123",
                experienceLocation: "home-page",
                action: InteractionType.view
            )
        ]
        
        let (collection, _) = metricsBuilder.buildExperienceMetrics(from: events)
        
        for experienceKey in collection.experienceKeys {
            guard let metrics = collection.metrics(for: experienceKey) else {
                XCTFail("Should have metrics for experience key")
                return
            }
            
            XCTAssertEqual(metrics.attributedAssets.count, 2, "Should include attributed assets from definition")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createAssetEvent(
        assetURL: String,
        assetLocation: String,
        action: InteractionType
    ) -> Event {
        let data: [String: Any] = [
            "assetURL": assetURL,
            "assetLocation": assetLocation,
            "interactionType": action.stringValue
        ]
        
        return Event(
            name: "Content Analytics Asset Event",
            type: EventType.genericTrack,
            source: EventSource.requestContent,
            data: data
        )
    }
    
    private func createExperienceEvent(
        experienceId: String,
        experienceLocation: String,
        action: InteractionType
    ) -> Event {
        let data: [String: Any] = [
            "experienceId": experienceId,
            "experienceLocation": experienceLocation,
            "interactionType": action.stringValue
        ]
        
        return Event(
            name: "Content Analytics Experience Event",
            type: EventType.genericTrack,
            source: EventSource.requestContent,
            data: data
        )
    }
    
    private func waitForConfiguration() {
        let startTime = Date()
        let timeout: TimeInterval = 1.0
        
        while stateManager.getCurrentConfiguration() == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
}
