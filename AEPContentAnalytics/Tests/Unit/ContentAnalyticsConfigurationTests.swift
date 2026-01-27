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

import XCTest
import AEPCore
import AEPServices
@testable import AEPContentAnalytics

/// Tests for configuration behavioral changes (enable/disable flags).
/// Config parsing and validation tested in ContentAnalyticsConfigurationValidationTests.
class ContentAnalyticsConfigurationTests: ContentAnalyticsTestBase {
    
    // MARK: - Helpers
    
    private func sendConfig(_ config: [String: Any]) {
        let event = Event(
            name: "Configuration Response Content",
            type: EventType.configuration,
            source: EventSource.responseContent,
            data: config
        )
        mockRuntime.simulateComingEvents(event)
        waitForAsync(timeout: 0.3)
    }
    
    private func trackAsset(url: String = "https://example.com/image.jpg", location: String = "home") -> [Event] {
        let trackEvent = TestEventFactory.createAssetEvent(
            url: url,
            location: location,
            interaction: .view
        )
        mockRuntime.simulateComingEvents(trackEvent)
        waitForAsync(timeout: 0.2)
        return mockRuntime.dispatchedEvents.filter { $0.type == EventType.edge }
    }
    
    // MARK: - Tests
    
    func testTrackExperiencesDisabled_BlocksExperienceEvents() {
        let config = ["contentanalytics.trackExperiences": false]
        
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        sendConfig(config)
        
        let initialCount = mockRuntime.dispatchedEvents.count
        
        let experienceEvent = TestEventFactory.createExperienceEvent(
            id: "test-exp",
            location: "home",
            interaction: .view
        )
        mockRuntime.simulateComingEvents(experienceEvent)
        waitForAsync(timeout: 0.2)
        
        let finalCount = mockRuntime.dispatchedEvents.count
        XCTAssertEqual(finalCount, initialCount, "trackExperiences:false blocks experience events")
    }
    
}
