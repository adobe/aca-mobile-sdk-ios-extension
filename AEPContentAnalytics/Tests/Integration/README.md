# Integration Tests

## Overview

Integration tests verify **component integration with real dependencies** (disk I/O, DataQueue, PersistentHitQueue), unlike unit tests which use mocks.

## Difference from E2E Tests

| Aspect | Integration Tests | E2E Tests |
|--------|-------------------|-----------|
| **Scope** | Component integration | Full extension flow |
| **Entry Point** | Direct component calls | Extension listener |
| **Focus** | Disk persistence, crash recovery | User-facing behavior |
| **Runtime** | Real `DataQueue` / `PersistentHitQueue` | `TestableExtensionRuntime` |
| **Speed** | ~0.6-3s per test | ~1-2s per test |
| **Example** | Add event → verify disk write | Track asset → verify Edge event |

See `Tests/E2E/README.md` for end-to-end tests that verify the complete extension flow.

## Why Custom Test Utilities?

We built our own lightweight helpers instead of using `aepsdk-testutils-ios` for a few reasons:

1. **Incompatibility with AEPCore 5.7.0** - The shared test utilities have API mismatches in `DataQueueService.threadSafeDictionary` and `ExtensionRuntime` protocol changes.

2. **Simplicity** - Our helpers are focused on what we need without extra dependency management overhead.

3. **Performance** - Faster test execution since there's no external dependency resolution.

## Test Structure

```
Integration/
├── README.md (this file)
├── IntegrationTestHelpers.swift       # Reusable utilities
├── BatchCoordinatorIntegrationTests.swift  # Batch + persistence tests
└── (future tests...)
```

## What Integration Tests Cover

**Covered:**
- Disk persistence (actual file I/O)
- Batch size triggers and auto-flush
- Crash recovery (events survive restart)
- Flush and clear operations

**Not covered here (use unit tests):**
- Orchestrator configuration
- Privacy validation
- URL exclusion logic
- XDM payload generation

## Running Integration Tests

### Run All Integration Tests
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/BatchCoordinatorIntegrationTests
```

### Run Single Test
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/BatchCoordinatorIntegrationTests/testCrashRecovery_EventsSurviveRestart
```

## Performance Characteristics

| Test Type | Speed | Disk I/O | External Deps | Pass Rate |
|-----------|-------|----------|---------------|-----------|
| Unit Tests | ~1ms | No | None | 100% (6/6) |
| Integration Tests | ~0.6-3s | Yes | None | 60% (3/5) |

Integration tests are slower because they write to actual disk and use real `DataQueue` / `PersistentHitQueue` with actual timing.

Pass rate: 3/5 after refactoring. See `INTEGRATION_TESTS_RESULTS.md` for details.

## Test Utilities API

### IntegrationTestHelpers

```swift
// Create temporary test directory
let testDir = IntegrationTestHelpers.createTestDataDirectory()

// Create real DataQueue
let dataQueue = IntegrationTestHelpers.createTestDataQueue(
    name: "test-queue",
    dataDirectory: testDir
)

// Wait for condition with timeout
let success = IntegrationTestHelpers.waitForCondition(timeout: 2.0) {
    return eventCount > 0
}

// Verify disk writes
let written = IntegrationTestHelpers.verifyDataWrittenToDisk(in: testDir)

// Count files
let count = IntegrationTestHelpers.countFilesInDirectory(testDir)

// Cleanup
IntegrationTestHelpers.cleanupTestDataDirectory(testDir)
```

### ContentAnalyticsIntegrationTestBase

```swift
final class MyIntegrationTests: ContentAnalyticsIntegrationTestBase {
    
    func testSomething() {
        // testDataDirectory is automatically created in setUp()
        // eventCapture is ready to use
        
        let coordinator = createTestBatchCoordinator()
        // ... test logic ...
        
        // Cleanup happens automatically in tearDown()
    }
}
```

### TestHitProcessor

```swift
let processor = TestHitProcessor(eventCapture: eventCapture)

processor.processHitCallback = { entity in
    // Custom verification logic
    print("Processing: \(entity)")
}

// Events are automatically captured in eventCapture
XCTAssertEqual(eventCapture.count, 3)
```

## Adding New Integration Tests

1. **Inherit from `ContentAnalyticsIntegrationTestBase`**:
   ```swift
   final class MyIntegrationTests: ContentAnalyticsIntegrationTestBase {
       // Automatic setup/teardown
   }
   ```

2. **Use helper methods**:
   ```swift
   let coordinator = createTestBatchCoordinator()
   // testDataDirectory and eventCapture are already available
   ```

3. **Clean up is automatic**:
   - Test data directory removed in `tearDown()`
   - No manual cleanup needed

## Best Practices

**Do:**
- Test real persistence scenarios
- Use `waitForCondition` for async operations
- Verify disk state explicitly
- Test crash recovery scenarios

**Don't:**
- Mock `DataQueue` or `PersistentHitQueue` (use unit tests)
- Add external test framework dependencies
- Write integration tests for logic that can be unit tested
- Forget to wait for async disk operations

## Examples

### Testing Persistence
```swift
func testEventsPersistToDisk() {
    // Add event
    coordinator.addAssetEvent(event)
    
    // Wait for async write
    let written = IntegrationTestHelpers.waitForCondition(timeout: 2.0) {
        IntegrationTestHelpers.verifyDataWrittenToDisk(in: self.testDataDirectory)
    }
    
    XCTAssertTrue(written)
}
```

### Testing Crash Recovery
```swift
func testCrashRecovery() {
    // Add events
    coordinator.addAssetEvent(event)
    
    // Simulate crash (recreate coordinator)
    coordinator = createTestBatchCoordinator()
    
    // Flush to read from disk
    coordinator.flush()
    
    // Verify events recovered
    XCTAssertEqual(eventCapture.count, 1)
}
```

## Future Enhancements

Potential additions:
- Performance benchmarks
- Concurrent access tests
- Memory pressure simulation
- Network failure scenarios
- Large batch handling (1000+ events)

## FAQs

**Why not use `aepsdk-testutils-ios`?**  
It's incompatible with AEPCore 5.7.0. Our custom helpers are simpler anyway.

**Are these tests slow?**  
Yes, ~100-500ms per test due to real disk I/O. That's expected.

**Should I write integration tests for everything?**  
No. Use unit tests for logic. Integration tests verify the system works end-to-end with real components.

**How do I debug failing tests?**  
Check `testDataDirectory` contents, add debug prints in `TestHitProcessor`, or increase wait timeouts.
