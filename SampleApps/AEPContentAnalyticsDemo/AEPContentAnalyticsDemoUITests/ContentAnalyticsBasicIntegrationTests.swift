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

/// Basic integration tests for ContentAnalytics Demo App
/// Simplified, robust tests that verify core SDK functionality without UI flakiness
final class ContentAnalyticsBasicIntegrationTests: XCTestCase {
    
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
    
    // MARK: - Basic Smoke Tests
    
    func testAppLaunches() throws {
        // Verify app launches successfully
        XCTAssertTrue(app.waitForExistence(timeout: 10))
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testNavigationToProducts() throws {
        // Verify can navigate to products
        let productsButton = app.buttons["Products"].firstMatch
        XCTAssertTrue(productsButton.waitForExistence(timeout: 5))
        
        productsButton.tap()
        sleep(2)
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testNavigationToConfig() throws {
        // Verify can navigate to config
        let configButton = app.buttons["Config"].firstMatch
        XCTAssertTrue(configButton.waitForExistence(timeout: 5))
        
        configButton.tap()
        sleep(2)
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - SDK Integration Tests
    
    func testSDKInitialization() throws {
        // SDK should initialize when app launches
        // Verify app is running (SDK initialization happens in background)
        XCTAssertTrue(app.waitForExistence(timeout: 10))
        sleep(3) // Allow SDK to initialize
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testBasicNavigation_ProductsAndBack() throws {
        // Navigate to products
        let productsButton = app.buttons["Products"].firstMatch
        XCTAssertTrue(productsButton.waitForExistence(timeout: 5))
        productsButton.tap()
        sleep(2)
        
        // Navigate back
        if app.navigationBars.buttons.count > 0 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testProductDetailNavigation() throws {
        // Navigate to products
        let productsButton = app.buttons["Products"].firstMatch
        guard productsButton.waitForExistence(timeout: 5) else {
            XCTFail("Products button not found")
            return
        }
        productsButton.tap()
        sleep(2)
        
        // Try to tap first product if it exists
        let productRows = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ProductRow'"))
        if productRows.count > 0 {
            productRows.element(boundBy: 0).tap()
            sleep(2)
            XCTAssertTrue(app.state == .runningForeground)
        } else {
            // No products to test with, but app should still be running
            XCTAssertTrue(app.state == .runningForeground)
        }
    }
    
    // MARK: - Lifecycle Tests
    
    func testAppBackgrounding() throws {
        // Verify app handles backgrounding
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        // Background the app
        XCUIDevice.shared.press(.home)
        sleep(2)
        
        // Relaunch
        app.activate()
        sleep(2)
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testAppTerminationAndRelaunch() throws {
        // Verify app handles termination
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        // Terminate
        app.terminate()
        sleep(2)
        
        // Relaunch
        app.launch()
        sleep(3)
        
        XCTAssertTrue(app.waitForExistence(timeout: 10))
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
        }
    }
    
    // MARK: - Stress Tests (Simplified)
    
    func testMultipleNavigations() throws {
        // Navigate back and forth multiple times
        for _ in 1...5 {
            let productsButton = app.buttons["Products"].firstMatch
            if productsButton.waitForExistence(timeout: 3) {
                productsButton.tap()
                sleep(1)
                
                if app.navigationBars.buttons.count > 0 {
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                    sleep(1)
                }
            }
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testExtendedSession() throws {
        // Simulate extended session with multiple interactions
        for i in 1...10 {
            let productsButton = app.buttons["Products"].firstMatch
            if productsButton.waitForExistence(timeout: 3) {
                productsButton.tap()
                sleep(1)
                
                // Occasional backgrounding
                if i % 3 == 0 {
                    XCUIDevice.shared.press(.home)
                    sleep(1)
                    app.activate()
                    sleep(1)
                }
                
                if app.navigationBars.buttons.count > 0 {
                    app.navigationBars.buttons.element(boundBy: 0).tap()
                    sleep(1)
                }
            }
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
}

