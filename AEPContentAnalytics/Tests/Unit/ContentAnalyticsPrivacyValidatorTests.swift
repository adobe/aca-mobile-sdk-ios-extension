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
@testable import AEPContentAnalytics

/// Tests for privacy validator: consent detection, shared state handling, and fallback behavior.
class ContentAnalyticsPrivacyValidatorTests: XCTestCase {
    
    var privacyValidator: StatePrivacyValidator!
    var mockRuntime: TestableExtensionRuntime!
    var stateManager: ContentAnalyticsStateManager!
    
    override func setUp() {
        super.setUp()
        mockRuntime = TestableExtensionRuntime()
        stateManager = ContentAnalyticsStateManager()
        privacyValidator = StatePrivacyValidator(state: stateManager, runtime: mockRuntime)
    }
    
    override func tearDown() {
        privacyValidator = nil
        mockRuntime = nil
        stateManager = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Set Hub shared state with Consent extension registered
    private func setHubStateWithConsent(registered: Bool) {
        var hubData: [String: Any] = [:]
        
        if registered {
            hubData[ContentAnalyticsConstants.HubSharedState.EXTENSIONS_KEY] = [
                ContentAnalyticsConstants.ExternalExtensions.CONSENT: [
                    "version": "1.0.0"
                ]
            ]
        } else {
            hubData[ContentAnalyticsConstants.HubSharedState.EXTENSIONS_KEY] = [:]
        }
        
        mockRuntime.setMockedSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.EVENT_HUB, data: hubData)
    }
    
    /// Set Consent shared state with specific value
    private func setConsentState(value: String) {
        let consentData: [String: Any] = [
            "consents": [
                "collect": [
                    "val": value
                ]
            ]
        ]
        // Use XDM shared state for Consent extension (not standard shared state)
        mockRuntime.simulateXDMSharedState(for: ContentAnalyticsConstants.ExternalExtensions.CONSENT, data: (value: consentData, status: .set))
    }
    
    /// Set malformed Consent shared state
    private func setMalformedConsentState() {
        let consentData: [String: Any] = [
            "invalid": "data"
        ]
        mockRuntime.setMockedSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.CONSENT, data: consentData)
    }
    
    // MARK: - Hub Shared State Tests
    
    func testIsDataCollectionAllowed_NoHubState_ReturnsFalse() {
        // Given - No Hub shared state
        // (mockRuntime has no states by default)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when Hub state is unavailable")
    }
    
    func testIsDataCollectionAllowed_HubStateAvailable_Proceeds() {
        // Given - Hub state available but Consent not registered
        setHubStateWithConsent(registered: false)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertTrue(allowed, "Should allow data collection when Consent not registered (default allow)")
    }
    
    // MARK: - Consent Extension Registration Tests
    
    func testIsDataCollectionAllowed_ConsentNotRegistered_ReturnsTrue() {
        // Given - Hub state shows Consent is NOT registered
        setHubStateWithConsent(registered: false)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertTrue(allowed, "Should allow data collection when Consent extension not registered")
    }
    
    func testIsDataCollectionAllowed_ConsentRegisteredButNoState_ReturnsFalse() {
        // Given - Consent is registered but has no shared state yet
        setHubStateWithConsent(registered: true)
        // Don't set Consent state - simulates Consent not booted yet
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when Consent registered but no state yet (pending)")
    }
    
    // MARK: - Consent Value Tests (Granted)
    
    func testIsDataCollectionAllowed_ConsentGranted_Y_ReturnsTrue() {
        // Given - Consent granted with "y"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "y")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertTrue(allowed, "Should allow data collection when consent is 'y'")
    }
    
    func testIsDataCollectionAllowed_ConsentGranted_Yes_ReturnsTrue() {
        // Given - Consent granted with "yes"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "yes")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertTrue(allowed, "Should allow data collection when consent is 'yes'")
    }
    
    func testIsDataCollectionAllowed_ConsentGranted_UppercaseY_ReturnsTrue() {
        // Given - Consent granted with "Y" (case insensitive)
        setHubStateWithConsent(registered: true)
        setConsentState(value: "Y")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertTrue(allowed, "Should allow data collection when consent is 'Y' (case insensitive)")
    }
    
    // MARK: - Consent Value Tests (Denied)
    
    func testIsDataCollectionAllowed_ConsentDenied_N_ReturnsFalse() {
        // Given - Consent denied with "n"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "n")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'n'")
    }
    
    func testIsDataCollectionAllowed_ConsentDenied_No_ReturnsFalse() {
        // Given - Consent denied with "no"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "no")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'no'")
    }
    
    func testIsDataCollectionAllowed_ConsentDenied_UppercaseN_ReturnsFalse() {
        // Given - Consent denied with "N" (case insensitive)
        setHubStateWithConsent(registered: true)
        setConsentState(value: "N")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'N' (case insensitive)")
    }
    
    // MARK: - Consent Value Tests (Pending)
    
    func testIsDataCollectionAllowed_ConsentPending_P_ReturnsFalse() {
        // Given - Consent pending with "p"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "p")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'p' (pending)")
    }
    
    func testIsDataCollectionAllowed_ConsentPending_Pending_ReturnsFalse() {
        // Given - Consent pending with "pending"
        setHubStateWithConsent(registered: true)
        setConsentState(value: "pending")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'pending'")
    }
    
    func testIsDataCollectionAllowed_ConsentPending_UppercaseP_ReturnsFalse() {
        // Given - Consent pending with "P" (case insensitive)
        setHubStateWithConsent(registered: true)
        setConsentState(value: "P")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent is 'P' (case insensitive)")
    }
    
    // MARK: - Invalid Consent Value Tests
    
    func testIsDataCollectionAllowed_ConsentInvalidValue_ReturnsFalse() {
        // Given - Consent with unrecognized value
        setHubStateWithConsent(registered: true)
        setConsentState(value: "invalid")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection for unrecognized consent value")
    }
    
    func testIsDataCollectionAllowed_ConsentEmptyValue_ReturnsFalse() {
        // Given - Consent with empty value
        setHubStateWithConsent(registered: true)
        setConsentState(value: "")
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection for empty consent value")
    }
    
    // MARK: - Malformed Data Tests
    
    func testIsDataCollectionAllowed_MalformedConsentData_ReturnsFalse() {
        // Given - Consent state with malformed data
        setHubStateWithConsent(registered: true)
        setMalformedConsentState()
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when consent data is malformed")
    }
    
    func testIsDataCollectionAllowed_ConsentStateMissingConsents_ReturnsFalse() {
        // Given - Consent state missing "consents" key
        setHubStateWithConsent(registered: true)
        let consentData: [String: Any] = [
            "other": "data"
        ]
        mockRuntime.setMockedSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.CONSENT, data: consentData)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when 'consents' key is missing")
    }
    
    func testIsDataCollectionAllowed_ConsentStateMissingCollect_ReturnsFalse() {
        // Given - Consent state missing "collect" key
        setHubStateWithConsent(registered: true)
        let consentData: [String: Any] = [
            "consents": [
                "other": "data"
            ]
        ]
        mockRuntime.setMockedSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.CONSENT, data: consentData)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when 'collect' key is missing")
    }
    
    func testIsDataCollectionAllowed_ConsentStateMissingVal_ReturnsFalse() {
        // Given - Consent state missing "val" key
        setHubStateWithConsent(registered: true)
        let consentData: [String: Any] = [
            "consents": [
                "collect": [
                    "other": "data"
                ]
            ]
        ]
        mockRuntime.setMockedSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.CONSENT, data: consentData)
        
        // When
        let allowed = privacyValidator.isDataCollectionAllowed()
        
        // Then
        XCTAssertFalse(allowed, "Should block data collection when 'val' key is missing")
    }
    
    // MARK: - Edge Case Tests
    
    func testIsDataCollectionAllowed_MultipleCallsSameState_ConsistentResults() {
        // Given - Consent granted
        setHubStateWithConsent(registered: true)
        setConsentState(value: "y")
        
        // When - Call multiple times
        let result1 = privacyValidator.isDataCollectionAllowed()
        let result2 = privacyValidator.isDataCollectionAllowed()
        let result3 = privacyValidator.isDataCollectionAllowed()
        
        // Then - All should return same result
        XCTAssertTrue(result1, "First call should return true")
        XCTAssertTrue(result2, "Second call should return true")
        XCTAssertTrue(result3, "Third call should return true")
    }
}

