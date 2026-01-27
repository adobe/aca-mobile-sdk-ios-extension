# End-to-End (E2E) Tests

## Overview

E2E tests verify the **complete extension flow** from public API calls through the full extension stack to Edge event dispatch. These tests use the real extension implementation with `TestableExtensionRuntime` to simulate the AEP SDK environment.

## What E2E Tests Cover

**Full Extension Flow:**
- Public API → Extension listener → Orchestrator → Edge event dispatch
- Configuration handling and state management
- Event routing and processing
- XDM payload generation
- Asset and experience tracking
- Extras merging and validation
- URL exclusion

**Test Scenarios:**
- ✅ Asset tracking dispatches Edge events
- ✅ Asset tracking with extras includes extras in XDM
- ✅ Multiple asset tracking dispatches multiple events
- ✅ Experience tracking dispatches Edge events
- ✅ Experience tracking without registration still processes
- ✅ Experience tracking with extras includes extras in XDM
- ✅ Batching enabled holds events (not dispatched immediately)
- ✅ Batching enabled holds events in batch
- ✅ Configuration change toggles batching behavior
- ✅ Configuration change updates exclusion patterns
- ✅ Excluded assets are not dispatched
- ✅ Non-excluded assets are dispatched

## Difference from Integration Tests

| Aspect | E2E Tests | Integration Tests |
|--------|-----------|-------------------|
| **Scope** | Full extension flow | Component integration |
| **Entry Point** | Extension listener | Direct component calls |
| **Runtime** | `TestableExtensionRuntime` | Real `DataQueue` / `PersistentHitQueue` |
| **Focus** | User-facing behavior | Disk persistence, crash recovery |
| **Speed** | ~1-2s per test | ~0.6-3s per test |
| **Example** | Track asset → verify Edge event | Add event → verify disk write |

## Test Structure

```
E2E/
├── README.md (this file)
└── ContentAnalyticsEndToEndTests.swift  # Full extension flow tests
```

## Running E2E Tests

### Run All E2E Tests
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/ContentAnalyticsEndToEndTests
```

### Run Single Test
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/ContentAnalyticsEndToEndTests/testAssetTracking_DispatachesEdgeEvent
```

## Test Architecture

### Setup Flow
1. Create `TestableExtensionRuntime` (mocks AEP SDK runtime)
2. Set configuration shared state
3. Create and register `ContentAnalytics` extension
4. Send configuration event
5. Wait for async configuration processing

### Test Flow
1. Create tracking event (asset or experience)
2. Simulate event coming to extension via `mockRuntime.simulateComingEvents()`
3. Wait for async processing
4. Verify Edge events dispatched via `mockRuntime.dispatchedEvents`
5. Validate XDM payload structure

### Teardown Flow
1. Unregister extension
2. Clean up runtime
3. Reset state

## Key Components

### TestableExtensionRuntime
Mocks the AEP SDK's `ExtensionRuntime`:
- Simulates shared state
- Captures dispatched events
- Routes events to registered listeners
- Provides configuration access

### Helper Methods
```swift
// Track asset and wait for processing
private func trackAssetAndWait(
    url: String,
    interaction: InteractionType = .view,
    location: String? = nil,
    additionalData: [String: Any]? = nil
)

// Register experience and wait
private func registerExperienceAndWait(
    assets: [ContentItem],
    texts: [ContentItem],
    ctas: [ContentItem]?,
    location: String
) -> String

// Track experience interaction
private func trackExperienceAndWait(
    experienceId: String,
    interaction: InteractionType = .view
)

// Wait for Edge events with timeout
private func waitForEdgeEvents(
    count: Int,
    timeout: TimeInterval = 5.0
) -> [Event]
```

## Event Names (Critical!)

**Public API Events** (used in tests):
- `ContentAnalyticsConstants.EventNames.TRACK_ASSET`
- `ContentAnalyticsConstants.EventNames.TRACK_EXPERIENCE`

**Internal Events** (dispatched to Edge):
- `ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_ASSET`
- `ContentAnalyticsConstants.EventNames.CONTENT_ANALYTICS_EXPERIENCE`

⚠️ **Important**: E2E tests MUST use `TRACK_*` event names, not `CONTENT_ANALYTICS_*`, as the extension's listener only recognizes the public API event names.

## XDM Payload Structure

### Asset Event
```json
{
  "xdm": {
    "eventType": "content.contentEngagement",
    "experienceContent": {
      "assets": [
        {
          "assetID": "https://example.com/image.jpg",
          "assetExtras": {
            "category": "product",
            "price": 99.99
          }
        }
      ]
    }
  }
}
```

### Experience Event
```json
{
  "xdm": {
    "eventType": "content.contentEngagement",
    "experienceContent": {
      "experience": {
        "experienceID": "exp-abc123",
        "experienceExtras": {
          "campaign": "summer-sale"
        }
      }
    }
  }
}
```

## Common Patterns

### Testing Asset Tracking
```swift
func testAssetTracking() {
    // Track asset
    trackAssetAndWait(
        url: "https://example.com/image.jpg",
        location: "home"
    )
    
    // Verify Edge event
    let edgeEvents = waitForEdgeEvents(count: 1)
    XCTAssertEqual(edgeEvents.count, 1)
    
    // Validate XDM
    let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
    let experienceContent = xdm?["experienceContent"] as? [String: Any]
    let assets = experienceContent?["assets"] as? [[String: Any]]
    
    XCTAssertEqual(assets?.first?["assetID"] as? String, "https://example.com/image.jpg")
}
```

### Testing Experience Tracking
```swift
func testExperienceTracking() {
    // Register experience
    let experienceId = registerExperienceAndWait(
        assets: [ContentItem(value: "https://example.com/hero.jpg")],
        texts: [ContentItem(value: "Welcome")],
        ctas: nil,
        location: "home"
    )
    
    // Reset events
    mockRuntime.resetDispatchedEventAndCreatedSharedStates()
    
    // Track interaction
    trackExperienceAndWait(experienceId: experienceId, interaction: .view)
    
    // Verify Edge event
    let edgeEvents = waitForEdgeEvents(count: 1)
    XCTAssertEqual(edgeEvents.count, 1)
}
```

### Testing Extras
```swift
func testExtras() {
    let extras = ["category": "product", "price": 99.99] as [String: Any]
    
    // Must wrap in assetExtras key!
    trackAssetAndWait(
        url: "https://example.com/product.jpg",
        location: "catalog",
        additionalData: [AssetTrackingEventPayload.OptionalFields.assetExtras: extras]
    )
    
    // Verify extras in XDM
    let edgeEvents = waitForEdgeEvents(count: 1)
    let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
    let experienceContent = xdm?["experienceContent"] as? [String: Any]
    let assets = experienceContent?["assets"] as? [[String: Any]]
    let assetExtras = assets?.first?["assetExtras"] as? [String: Any]
    
    XCTAssertEqual(assetExtras?["category"] as? String, "product")
    XCTAssertEqual(assetExtras?["price"] as? Double, 99.99)
}
```

## Best Practices

**Do:**
- Test complete user-facing flows
- Verify Edge event dispatch
- Validate XDM payload structure
- Use helper methods for common operations
- Wait for async processing with appropriate timeouts
- Reset dispatched events between test phases

**Don't:**
- Test internal component logic (use unit tests)
- Test disk persistence (use integration tests)
- Mock the extension or orchestrator
- Use `CONTENT_ANALYTICS_*` event names (use `TRACK_*`)
- Forget to wait for async configuration processing

## Debugging Tips

### No Events Dispatched
1. Check event names (must use `TRACK_*`)
2. Verify configuration is set correctly
3. Increase wait timeout
4. Check `readyForEvent` returns true
5. Verify listener is registered

### Wrong XDM Structure
1. Check `XDMEventBuilder` implementation
2. Verify extras are wrapped in correct key
3. Use `print(edgeEvents.first?.data)` to inspect payload

### Flaky Tests
1. Increase `Thread.sleep` durations
2. Use `waitForEdgeEvents` with longer timeout
3. Check for race conditions in async processing

## Performance Characteristics

| Metric | Value |
|--------|-------|
| **Test Count** | 12 tests |
| **Pass Rate** | 100% (12/12) |
| **Avg Duration** | ~2.3s per test |
| **Total Suite Time** | ~28s |

E2E tests are slower than unit tests due to:
- Full extension initialization
- Async configuration processing
- Event routing through listeners
- XDM payload generation

## Adding New E2E Tests

1. **Follow existing patterns**:
   ```swift
   func testNewScenario() {
       // Setup
       trackAssetAndWait(...)
       
       // Verify
       let edgeEvents = waitForEdgeEvents(count: 1)
       XCTAssertEqual(edgeEvents.count, 1)
       
       // Validate XDM
       let xdm = edgeEvents.first?.data?["xdm"] as? [String: Any]
       // ... assertions ...
   }
   ```

2. **Use helper methods** for common operations

3. **Test user-facing scenarios**, not internal logic

4. **Verify Edge events**, not internal state

## Future Enhancements

Potential additions:
- Privacy/consent flow tests
- Configuration change tests
- Lifecycle event tests
- Error handling scenarios
- High-volume event tests
- Network failure simulation

## FAQs

**Why separate E2E from integration tests?**  
Different focus: E2E tests verify user-facing flows, integration tests verify component integration with real dependencies.

**Should I add more E2E tests?**  
Only if testing new user-facing scenarios. Most logic should be unit tested.

**Why are E2E tests slower?**  
They test the full extension stack with async processing. That's expected and valuable.

**Can I mock components in E2E tests?**  
No. E2E tests use the real extension. Use unit tests for mocked components.

