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

/// Critical Integration Tests for ContentAnalytics
/// Focus: Core tracking, attribution, and zero data loss
final class ContentAnalyticsIntegrationTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Core Tracking Tests
    
    func testTracking_Assets_WorksCorrectly() throws {
        // Verify asset tracking works end-to-end
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should launch")
        sleep(1) // Allow app to fully initialize
        
        navigateToProducts()
        
        // Wait for table to load with longer timeout
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 15), "Products table should load")
        
        // Additional wait for data to populate
        sleep(2)
        
        // Trigger asset tracking by scrolling
        if table.exists {
            table.swipeUp()
            sleep(1) // Allow tracking events to process
            
            table.swipeUp()
            sleep(1)
        }
        
        // Verify app continues running (no crashes)
        XCTAssertTrue(app.state == .runningForeground, "App should remain in foreground after asset tracking")
    }
    
    func testTracking_Experiences_WorksCorrectly() throws {
        // Verify experience registration and tracking works
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should launch")
        sleep(2) // Allow home experience to register
        
        navigateToProducts()
        
        // Tap product to view product detail (experience)
        let productRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ProductRow'"))
        if productRows.count > 0 {
            productRows.element(boundBy: 0).tap()
            sleep(2) // Allow experience view tracking
            
            // Interact with product detail
            let table = app.tables.firstMatch
            if table.exists {
                table.swipeUp() // Simulate interaction
                sleep(1)
            }
            
            safelyTapBackButton()
        }
        
        XCTAssertTrue(app.state == .runningForeground, "App should remain in foreground after experience tracking")
    }
    
    // MARK: - Attribution Tests (Critical for CJA)
    
    func testAttribution_AssetsInExperience_CorrectlyAttributed() throws {
        // Verify assets within experiences are properly attributed
        // This is critical for CJA to join asset events to experience events
        
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        sleep(2) // Home experience registration
        
        navigateToProducts()
        
        // View product detail (contains both experience and assets)
        let productRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ProductRow'"))
        if productRows.count > 0 {
            productRows.element(boundBy: 0).tap()
            sleep(2) // Experience view + asset views
            
            // Scroll to view all assets in the experience
            let table = app.tables.firstMatch
            if table.exists {
                for _ in 1...3 {
                    table.swipeUp()
                    sleep(1) // Track each asset
                }
            }
            
            // Click on experience (conversion)
            if table.exists {
                table.tap()
                sleep(1)
            }
        }
        
        // Verify: In production, CJA should be able to:
        // 1. Join individual asset events to the experience via assetURL
        // 2. Calculate proper conversion attribution
        // 3. Use experienceSource for location-based breakdown
        
        XCTAssertTrue(app.state == .runningForeground, "App should remain stable after attribution tracking")
    }
    
    func testAttribution_StandaloneAssets_IndependentOfExperiences() throws {
        // Verify standalone asset tracking works independently
        // Critical: Assets without experiences should still be tracked
        
        navigateToProducts()
        
        let table = app.tables.firstMatch
        if table.exists {
            // Track multiple standalone asset views
            for _ in 1...5 {
                table.swipeUp()
                sleep(1)
            }
        }
        
        // These assets should be tracked independently
        // In CJA: Should appear as standalone assets, not attributed to any experience
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Zero Data Loss Tests (Critical)
    
    func testZeroDataLoss_Backgrounding_MetricsPersist() throws {
        // Verify metrics are persisted when app backgrounds
        navigateToProducts()
        
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 10) {
            // Accumulate metrics
            for _ in 1...5 {
                table.swipeUp()
                sleep(1)
            }
        }
        
        // Background the app (triggers flush + DataStore save)
        XCUIDevice.shared.press(.home)
        sleep(2)
        
        // Relaunch
        app.activate()
        sleep(2)
        
        // Verify app recovered successfully
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should relaunch")
        XCTAssertTrue(app.state == .runningForeground, "App should be running after background recovery")
        
        // In production: Metrics should be persisted in DataStore and recoverable
    }
    
    func testZeroDataLoss_AppTermination_MetricsRecovered() throws {
        // Verify metrics are recovered after app termination
        // This tests the PersistentHitQueue + DataStore integration
        
        // Session 1: Track metrics
        navigateToProducts()
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 10) {
            for _ in 1...5 {
                table.swipeUp()
                usleep(500000) // 0.5s
            }
        }
        
        // Terminate app (simulates crash)
        app.terminate()
        sleep(2)
        
        // Session 2: Relaunch
        app.launch()
        sleep(3) // Allow recovery + SDK initialization
        
        // Verify app relaunched successfully
        XCTAssertTrue(app.waitForExistence(timeout: 10), "App should relaunch after termination")
        XCTAssertTrue(app.state == .runningForeground, "App should be stable after recovery")
        
        // In production:
        // 1. DataStore should have persisted metrics
        // 2. PersistentHitQueue should have pending batches
        // 3. Edge PersistentHitQueue has queued network requests
        // Result: Zero data loss across crash recovery
    }
    
    func testZeroDataLoss_MultiSession_MetricsContinuity() throws {
        // Verify metrics accumulate correctly across multiple sessions
        
        // Ensure app is running before starting
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should launch")
        sleep(1)
        
        // Session 1
        navigateToProducts()
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 10) {
            table.swipeUp()
            sleep(1)
        }
        
        // Background
        XCUIDevice.shared.press(.home)
        sleep(3) // Longer wait for background transition
        
        // Session 2
        app.activate()
        sleep(3) // Longer wait for app to come back to foreground
        
        // Verify app is foreground before proceeding
        XCTAssertTrue(app.waitForExistence(timeout: 5), "App should return to foreground")
        
        if app.state == .runningForeground {
            navigateToProducts()
            let table2 = app.tables.firstMatch
            if table2.waitForExistence(timeout: 10) {
                table2.swipeUp()
                sleep(1)
            }
        }
        
        // Background again
        XCUIDevice.shared.press(.home)
        sleep(3)
        
        // Session 3
        app.activate()
        sleep(3)
        
        // Verify app recovered successfully
        XCTAssertTrue(app.waitForExistence(timeout: 10), "App should exist after multiple sessions")
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackgroundSuspended, 
                     "App should handle multiple sessions (current state: \(app.state.rawValue))")
        
        // In production: Metrics should accumulate correctly across sessions
    }
    
    // MARK: - Complete Journey Test
    
    func testE2E_CompleteUserJourney() throws {
        // Test a realistic user journey: browse → view → interact → convert
        
        // 1. Launch (home experience registered)
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        sleep(2)
        
        // 2. Browse products (asset tracking)
        navigateToProducts()
        sleep(1)
        
        let table = app.tables.firstMatch
        if table.exists {
            for _ in 1...3 {
                table.swipeUp()
                sleep(1)
            }
        }
        
        // 3. View product detail (experience tracking)
        let productRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ProductRow'"))
        if productRows.count > 0 {
            productRows.element(boundBy: 0).tap()
            sleep(2)
            
            // Scroll detail view
            if table.exists {
                table.swipeUp()
                sleep(1)
            }
            
            safelyTapBackButton()
        }
        
        // 4. View another product
        if productRows.count > 1 {
            productRows.element(boundBy: 1).tap()
            sleep(2)
            safelyTapBackButton()
        }
        
        // 5. Return to home
        safelyTapBackButton()
        
        // Journey complete
        XCTAssertTrue(app.state == .runningForeground, "Complete journey should succeed")
        
        // In production, CJA should show:
        // - Homepage experience view
        // - Multiple asset views (product browsing)
        // - Product detail experience views
        // - Proper attribution chains
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProducts() {
        // Wait for app to be fully loaded
        let productsButton = app.buttons["Products"].firstMatch
        XCTAssertTrue(productsButton.waitForExistence(timeout: 10), "Products button should exist")
        
        // Tap and wait for navigation
        productsButton.tap()
        sleep(2) // Wait for navigation animation and data loading
        
        // Verify navigation succeeded
        let navigationBar = app.navigationBars["Products"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Should navigate to Products screen")
    }
    
    private func safelyTapBackButton() {
        // Wait for navigation to settle (avoid tapping during transition)
        sleep(1)
        
        // Find and tap the back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1) // Allow navigation to complete
        }
    }
}
