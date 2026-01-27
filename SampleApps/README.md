# AEPContentAnalytics Demo App

Sample iOS app showing ContentAnalytics SDK integration.

## Features

- Asset tracking with `TrackedAsyncImage`
- Experience tracking with `TrackedExperienceView`
- E-commerce product catalog example
- Runtime SDK configuration
- Consent management

## Quick Start

### 1. Open the Project

```bash
cd SampleApps/AEPContentAnalyticsDemo
open AEPContentAnalyticsDemo.xcodeproj
```

### 2. Configure SDK

Edit `MobileSDK.swift` to add your Adobe credentials:

```swift
"experienceCloud.org": "YOUR_ORG_ID@AdobeOrg",
"edge.configId": "YOUR_DATASTREAM_ID",
"contentanalytics.featurizationServiceUrl": "YOUR_FEATURIZATION_URL"
```

### 3. Run the App

Select iPhone 16 (or any iOS 12+ simulator/device) and press `Cmd+R`.

## Testing

### Unit Tests (App Logic)

Test data models and utilities:

```bash
# Command line
xcodebuild test \
  -project AEPContentAnalyticsDemo.xcodeproj \
  -scheme AEPContentAnalyticsDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsDemoTests

# Xcode
1. Select AEPContentAnalyticsDemo scheme
2. Press Cmd+U
3. Or Product > Test
```

Tests JSON data loading, model validation, and helper functions.

---

### UI Tests (End-to-End Integration)

Test real SDK behavior in the app:

```bash
# Command line
xcodebuild test \
  -project AEPContentAnalyticsDemo.xcodeproj \
  -scheme AEPContentAnalyticsDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsDemoUITests

# Xcode
1. Select AEPContentAnalyticsDemo scheme
2. Press Cmd+U (runs all tests including UI)
3. Or right-click UI test file > Run tests
```

Tests asset tracking, experience registration, batching, background flushing, consent, crash recovery, and navigation flows.

**Test files:**

1. **ContentAnalyticsUITests.swift** (2 basic tests)
   - App launch verification
   - Basic navigation smoke test

2. **ContentAnalyticsIntegrationTests.swift** (52 integration tests)

**Test Categories:**

### Integration Tests (10 tests)
- E2E asset tracking flow
- E2E experience registration and tracking
- Multiple assets aggregation
- Batching with multiple events
- Background flush triggers
- Mixed assets and experiences
- Rapid fire event handling

### E2E Tests (Complete User Journeys) (5 tests)
- Complete shopping journey (browse → view → convert)
- Multi-session with backgrounding
- Crash recovery with simulated termination
- Asset and experience attribution
- Mixed standalone and experience-bound tracking

### CJA Attribution Tests (4 tests) - Critical for Reporting
- Experience with multiple assets
- Standalone asset tracking
- Same asset in multiple experiences (different attribution via experienceSource)
- Metrics aggregation across batches (no duplicates)

### Featurization Service Tests (3 tests)
- Experience registration
- Experience deduplication (content hash)
- Tracking works even if featurization service is down

### Metrics Reset Validation (2 tests) - Critical for Data Quality
- No duplicate counts across batches (delta metrics only)
- Assets preserved for CJA joins after reset

### Lifecycle Integration Tests (3 tests)
- Background flush with pending metrics
- Crash recovery with metrics persistence
- Long session metrics continuity

### Advanced Stress Tests (8 tests)
- Rapid product browsing (100 interactions)
- Rapid asset scrolling (20 swipes)
- Multiple product views (5 products)
- Concurrent navigation (10 cycles)
- Extended session (100 interactions)
- Burst pattern (multiple cycles)
- Memory pressure (500 swipes)
- Extended scrolling

### Performance Tests (3 tests)
- App launch metrics
- Product list scrolling performance
- Product detail navigation performance

### Edge Cases (2 tests)
- Empty product list handling
- Rapid back navigation

### Error Recovery (2 tests)
- Network outage (queued events)
- Low disk space (graceful degradation)

---

### Run Specific Tests

```bash
# Single test
xcodebuild test \
  -project AEPContentAnalyticsDemo.xcodeproj \
  -scheme AEPContentAnalyticsDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsDemoUITests/ContentAnalyticsUITests/testAssetTracking_ProductImage

# Test class
xcodebuild test \
  -project AEPContentAnalyticsDemo.xcodeproj \
  -scheme AEPContentAnalyticsDemo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsDemoUITests/ContentAnalyticsUITests
```

## Monitoring Test Results

### Xcode Test Report

1. Run tests (Cmd+U)
2. Open Report Navigator (Cmd+9)
3. Select latest test run
4. View detailed results with logs

### Console Logs

Enable verbose SDK logging to see events:

```swift
// In MobileSDK.swift
MobileCore.setLogLevel(.trace)
```

Look for logs like:
```
Asset tracked | URL: https://... | Type: view | Location: products
Batch created | Assets: 5 | Experiences: 2
Batch dispatched to Edge Network
Experience registered | ID: abc123
```

### Network Traffic

Use **Charles Proxy** or **Proxyman** to inspect:

1. **Edge Network Requests**
   - POST to `edge.adobedc.net`
   - XDM payload with `experienceContent`

2. **Featurization Requests**
   - POST to featurization service
   - Experience registration payloads

3. **Expected Endpoints**
   ```
   https://edge.adobedc.net/ee/v1/interact
   https://your-featurization-service.com/register/{org}/{experienceId}
   ```

## Debugging UI Tests

### Common Issues

**1. Test Times Out**
```swift
// Increase wait timeout
XCTAssertTrue(app.waitForExistence(timeout: 10))
```

**2. Element Not Found**
```swift
// Print view hierarchy
print(app.debugDescription)

// Or use accessibility inspector in Xcode
```

**3. Flaky Tests**
```swift
// Add delays for async operations
sleep(2) // Allow SDK events to process

// Or use expectations
let expectation = XCTNSPredicateExpectation(
    predicate: NSPredicate(format: "exists == true"),
    object: app.buttons["Products"]
)
wait(for: [expectation], timeout: 5)
```

**4. Network Issues**
- Check internet connection
- Verify SDK configuration (org ID, datastream ID)
- Check firewall/proxy settings

### Enable Test Debugging

```swift
// In test setUp
override func setUpWithError() throws {
    continueAfterFailure = false // Stop on first failure
    
    app = XCUIApplication()
    app.launchArguments = [
        "UI_TESTING",
        "-com.apple.CoreData.ConcurrencyDebug", "1",
        "-com.adobe.ContentAnalytics.logLevel", "TRACE"
    ]
    app.launch()
}
```

### Screenshot on Failure

```swift
override func tearDown() {
    if testRun?.hasSucceeded == false {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    super.tearDown()
}
```

## UI Test Best Practices

### 1. Use Accessibility Identifiers

In your SwiftUI views:

```swift
TrackedAsyncImage(url: assetURL)
    .accessibilityIdentifier("TrackedAsyncImage")

TrackedExperienceView(experienceId: expId) {
    // content
}
.accessibilityIdentifier("TrackedExperienceView")
```

### 2. Add Test Hooks

```swift
// In app code
#if DEBUG
if ProcessInfo.processInfo.arguments.contains("UI_TESTING") {
    // Disable animations
    UIView.setAnimationsEnabled(false)
    
    // Use mock data
    useMockProducts = true
}
#endif
```

### 3. Isolate Tests

```swift
override func setUp() {
    // Reset app state between tests
    app.launchArguments = ["RESET_STATE"]
    app.launch()
}
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Demo App Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
      - name: Run Unit Tests
        run: |
          cd SampleApps/AEPContentAnalyticsDemo
          xcodebuild test \
            -project AEPContentAnalyticsDemo.xcodeproj \
            -scheme AEPContentAnalyticsDemo \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -only-testing:AEPContentAnalyticsDemoTests
      
      - name: Run UI Tests
        run: |
          cd SampleApps/AEPContentAnalyticsDemo
          xcodebuild test \
            -project AEPContentAnalyticsDemo.xcodeproj \
            -scheme AEPContentAnalyticsDemo \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -only-testing:AEPContentAnalyticsDemoUITests
```

## Additional Resources

- **SDK Unit Tests**: `../../AEPContentAnalytics/Tests/Unit/`
- **SDK Integration Tests**: `../../AEPContentAnalytics/Tests/Integration/`
- **API Documentation**: `../../Documentation/api-reference.md`
- **Troubleshooting**: `../../Documentation/troubleshooting.md`

## Contributing

When adding new features:

1. **Add UI Test**: Cover user-facing functionality
2. **Update README**: Document new test scenarios
3. **Add Accessibility IDs**: For new UI elements
4. **Test on Device**: Verify on real hardware

## FAQ

**Q: How long do UI tests take?**  
A: ~30-60 seconds for full suite, ~5-10 seconds per test

**Q: Do I need a real Adobe org for testing?**  
A: No, but some tests will skip network verification without valid credentials

**Q: Can I test on a real device?**  
A: Yes! Select your device as destination in Xcode

**Q: Why are some tests failing?**  
A: Check:
- Simulator is launched and booted
- Network connectivity
- SDK configuration in `MobileSDK.swift`
- Xcode version (15.0+)

**Q: How do I add new tests?**  
A: Add methods starting with `test` in `ContentAnalyticsUITests.swift`
