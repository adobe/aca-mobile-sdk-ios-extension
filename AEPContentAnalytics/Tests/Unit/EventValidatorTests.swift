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

/// Tests for EventValidator - validates incoming asset and experience events
final class EventValidatorTests: XCTestCase {
    
    var stateManager: ContentAnalyticsStateManager!
    var validator: EventValidator!
    
    override func setUp() {
        super.setUp()
        stateManager = ContentAnalyticsStateManager()
        validator = EventValidator(state: stateManager)
        
        // Apply configuration
        var config = ContentAnalyticsConfiguration()
        config.trackExperiences = true
        stateManager.updateConfiguration(config)
        waitForConfiguration()
    }
    
    override func tearDown() {
        validator = nil
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Asset Validation Tests
    
    func testValidateAssetEvent_withValidEvent_returnsSuccess() {
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetKey: "asset-key-1",
            action: InteractionType.view
        )
        
        let result = validator.validateAssetEvent(event)
        
        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }
    
    func testValidateAssetEvent_withMissingAssetURL_returnsFailure() {
        let event = createAssetEvent(
            assetURL: nil,
            assetKey: "asset-key-1",
            action: InteractionType.view
        )
        
        let result = validator.validateAssetEvent(event)
        
        switch result {
        case .success:
            XCTFail("Expected failure for missing assetURL")
        case .failure(let error):
            if case .validationError = error {
                // Expected
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testValidateAssetEvent_withMissingAction_returnsFailure() {
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetKey: "asset-key-1",
            action: nil
        )
        
        let result = validator.validateAssetEvent(event)
        
        switch result {
        case .success:
            XCTFail("Expected failure for missing action")
        case .failure:
            // Expected
            break
        }
    }
    
    func testValidateAssetEvent_withInvalidAction_returnsFailure() {
        let event = createAssetEvent(
            assetURL: "https://example.com/image.jpg",
            assetKey: "asset-key-1",
            action: InteractionType.definition // Invalid for asset events
        )
        
        let result = validator.validateAssetEvent(event)
        
        switch result {
        case .success:
            XCTFail("Expected failure for invalid action")
        case .failure:
            // Expected
            break
        }
    }
    
    // MARK: - Experience Validation Tests
    
    func testValidateExperienceEvent_withValidEvent_returnsSuccess() {
        let event = createExperienceEvent(
            experienceId: "exp-123",
            experienceKey: "exp-key-1",
            action: InteractionType.view
        )
        
        let result = validator.validateExperienceEvent(event)
        
        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }
    
    func testValidateExperienceEvent_withDefinitionAction_returnsSuccess() {
        let event = createExperienceEvent(
            experienceId: "exp-123",
            experienceKey: "exp-key-1",
            action: InteractionType.definition
        )
        
        let result = validator.validateExperienceEvent(event)
        
        switch result {
        case .success:
            // Expected - definition is valid for experience events
            break
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }
    }
    
    func testValidateExperienceEvent_withMissingExperienceId_returnsFailure() {
        let event = createExperienceEvent(
            experienceId: nil,
            experienceKey: "exp-key-1",
            action: InteractionType.view
        )
        
        let result = validator.validateExperienceEvent(event)
        
        switch result {
        case .success:
            XCTFail("Expected failure for missing experienceId")
        case .failure:
            // Expected
            break
        }
    }
    
    // MARK: - Processing Conditions Tests
    
    func testValidateProcessingConditions_withValidConfiguration_returnsNil() {
        // Configuration was set in setUp
        let error = validator.validateProcessingConditions()
        XCTAssertNil(error, "Should return nil when configuration is valid")
    }
    
    func testValidateProcessingConditions_withoutConfiguration_returnsError() {
        let emptyStateManager = ContentAnalyticsStateManager()
        let validatorWithoutConfig = EventValidator(state: emptyStateManager)
        
        let error = validatorWithoutConfig.validateProcessingConditions()
        XCTAssertNotNil(error, "Should return error when configuration is missing")
    }
    
    // MARK: - Experience Tracking Enabled Tests
    
    func testIsExperienceTrackingEnabled_withTrackExperiencesTrue_returnsTrue() {
        var config = ContentAnalyticsConfiguration()
        config.trackExperiences = true
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        XCTAssertTrue(validator.isExperienceTrackingEnabled())
    }
    
    func testIsExperienceTrackingEnabled_withTrackExperiencesFalse_returnsFalse() {
        var config = ContentAnalyticsConfiguration()
        config.trackExperiences = false
        stateManager.updateConfiguration(config)
        waitForConfiguration()
        
        XCTAssertFalse(validator.isExperienceTrackingEnabled())
    }
    
    // MARK: - Helper Methods
    
    private func createAssetEvent(
        assetURL: String?,
        assetKey: String?,
        action: InteractionType?
    ) -> Event {
        var data: [String: Any] = [:]
        
        if let assetURL = assetURL {
            data["assetURL"] = assetURL
        }
        if let action = action {
            data["interactionType"] = action.stringValue
        }
        if let assetKey = assetKey {
            data["assetKey"] = assetKey
        }
        
        return Event(
            name: "Content Analytics Asset Event",
            type: EventType.genericTrack,
            source: EventSource.requestContent,
            data: data
        )
    }
    
    private func createExperienceEvent(
        experienceId: String?,
        experienceKey: String?,
        action: InteractionType?
    ) -> Event {
        var data: [String: Any] = [:]
        
        if let experienceId = experienceId {
            data["experienceId"] = experienceId
        }
        if let action = action {
            data["interactionType"] = action.stringValue
        }
        if let experienceKey = experienceKey {
            data["experienceKey"] = experienceKey
        }
        
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
