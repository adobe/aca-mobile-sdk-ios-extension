# AEPContentAnalytics Test Suite

## Overview

Comprehensive test suite for the AEPContentAnalytics extension with **305 tests** covering unit, integration, and end-to-end scenarios.

## Test Structure

```
Tests/
├── README.md (this file)
├── Unit/                          # 290 unit tests
│   ├── README.md
│   ├── ContentAnalyticsBatchCoordinatorTests.swift
│   ├── ContentAnalyticsConfigurationTests.swift
│   ├── ContentAnalyticsConfigurationValidationTests.swift
│   ├── ContentAnalyticsEdgeEventDispatcherTests.swift
│   ├── ContentAnalyticsErrorHandlingTests.swift
│   ├── ContentAnalyticsEventExtensionsTests.swift
│   ├── ContentAnalyticsExclusionTests.swift
│   ├── ContentAnalyticsExtrasMergingTests.swift
│   ├── ContentAnalyticsFactoryTests.swift
│   ├── ContentAnalyticsFeaturizationTests.swift
│   ├── ContentAnalyticsLocationKeyGenerationTests.swift
│   ├── ContentAnalyticsOrchestratorBehaviorTests.swift
│   ├── ContentAnalyticsOrchestratorConfigurationTests.swift
│   ├── ContentAnalyticsPrivacyValidatorTests.swift
│   ├── ContentAnalyticsPublicAPIComprehensiveTests.swift
│   ├── ContentAnalyticsPublicAPITests.swift
│   ├── ContentAnalyticsStateManagerTests.swift
│   ├── ContentAnalyticsUtilitiesTests.swift
│   └── XDMEventBuilderTests.swift
├── Integration/                   # 3 integration tests
│   ├── README.md
│   ├── IntegrationTestHelpers.swift
│   └── BatchCoordinatorIntegrationTests.swift
├── E2E/                          # 12 end-to-end tests
│   ├── README.md
│   └── ContentAnalyticsEndToEndTests.swift
├── Helpers/                      # Test utilities
│   ├── ContentAnalyticsMocks.swift
│   ├── ContentAnalyticsTestBase.swift
│   ├── ContentAnalyticsTestHelpers.swift
│   ├── TestAssertions.swift
│   ├── TestDataBuilder.swift
│   └── TestEventFactory.swift
└── TestHelpers/                  # Runtime mocks
    └── TestableExtensionRuntime.swift
```

## Test Categories

### Unit Tests (290 tests)
**Focus**: Individual component logic with mocked dependencies

**Coverage**:
- ✅ Orchestrator behavior and configuration
- ✅ Batch coordinator logic
- ✅ State management
- ✅ Privacy validation
- ✅ Event processing
- ✅ XDM payload generation
- ✅ URL exclusion
- ✅ Extras merging
- ✅ Key generation
- ✅ Error handling
- ✅ Public API

**Speed**: ~1ms per test  
**Pass Rate**: 100% (290/290)

See `Unit/README.md` for details.

### Integration Tests (3 tests)
**Focus**: Component integration with real dependencies (disk I/O, DataQueue)

**Coverage**:
- ✅ Events persist to disk
- ✅ Clear operations remove persisted events
- ✅ Flush operations reset counters

**Speed**: ~0.6-3s per test  
**Pass Rate**: 100% (3/3)

See `Integration/README.md` for details.

### End-to-End Tests (12 tests)
**Focus**: Full extension flow from public API to Edge event dispatch

**Coverage**:
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

**Speed**: ~2-3s per test  
**Pass Rate**: 100% (12/12)

See `E2E/README.md` for details.

## Test Comparison

| Aspect | Unit Tests | Integration Tests | E2E Tests |
|--------|-----------|-------------------|-----------|
| **Count** | 290 | 3 | 7 |
| **Scope** | Component logic | Component integration | Full extension flow |
| **Dependencies** | Mocked | Real (DataQueue, disk) | Real extension + mocked runtime |
| **Entry Point** | Direct method calls | Component API | Extension listener |
| **Speed** | ~1ms | ~0.6-3s | ~1-2s |
| **Focus** | Logic correctness | Disk persistence | User-facing behavior |
| **Example** | Test metrics calculation | Test event persists to disk | Test asset tracking → Edge event |

## Running Tests

### Run All Tests (300 tests)
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Run Unit Tests Only (290 tests)
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests
```

### Run Integration Tests Only (3 tests)
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/BatchCoordinatorIntegrationTests
```

### Run E2E Tests Only (7 tests)
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/ContentAnalyticsEndToEndTests
```

### Run Specific Test
```bash
xcodebuild test -scheme AEPContentAnalytics \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AEPContentAnalyticsTests/ContentAnalyticsOrchestratorBehaviorTests/testAssetEvent_WithBatchingDisabled_DispatchesImmediately
```

## Test Results Summary

| Category | Tests | Pass | Fail | Pass Rate | Avg Duration |
|----------|-------|------|------|-----------|--------------|
| **Unit** | 290 | 290 | 0 | 100% | ~1ms |
| **Integration** | 3 | 3 | 0 | 100% | ~1.1s |
| **E2E** | 7 | 7 | 0 | 100% | ~1.8s |
| **TOTAL** | **300** | **300** | **0** | **100%** | **~37s** |

## Test Utilities

### Test Helpers (`Helpers/`)
Reusable utilities for creating test data and assertions:

- **`TestEventFactory`**: Create test events (asset, experience, Edge)
- **`TestDataBuilder`**: Build test configurations and content items
- **`TestAssertions`**: Custom assertions for common checks
- **`ContentAnalyticsMocks`**: Mock implementations of protocols
- **`ContentAnalyticsTestBase`**: Base class for unit tests (setup/teardown)
- **`ContentAnalyticsTestHelpers`**: Utility functions for tests

### Runtime Mocks (`TestHelpers/`)
Mock implementations of AEP SDK components:

- **`TestableExtensionRuntime`**: Mocks `ExtensionRuntime` for testing extensions

### Integration Helpers (`Integration/`)
Utilities for integration tests:

- **`IntegrationTestHelpers`**: Create test directories, DataQueues, wait for conditions
- **`ContentAnalyticsIntegrationTestBase`**: Base class for integration tests
- **`TestHitProcessor`**: Mock hit processor for capturing events

## Coverage Analysis

### Core Components
| Component | Unit Tests | Integration Tests | E2E Tests | Total Coverage |
|-----------|-----------|-------------------|-----------|----------------|
| **Orchestrator** | ✅ 45 tests | - | ✅ 7 tests | Comprehensive |
| **BatchCoordinator** | ✅ 28 tests | ✅ 3 tests | - | Comprehensive |
| **StateManager** | ✅ 35 tests | - | - | Comprehensive |
| **XDMEventBuilder** | ✅ 50 tests | - | ✅ Verified | Comprehensive |
| **EdgeEventDispatcher** | ✅ 5 tests | - | ✅ Verified | Comprehensive |
| **PrivacyValidator** | ✅ 15 tests | - | - | Comprehensive |
| **Public API** | ✅ 25 tests | - | ✅ 7 tests | Comprehensive |

### Feature Coverage
| Feature | Unit Tests | Integration Tests | E2E Tests | Total Coverage |
|---------|-----------|-------------------|-----------|----------------|
| **Asset Tracking** | ✅ | - | ✅ | Comprehensive |
| **Experience Tracking** | ✅ | - | ✅ | Comprehensive |
| **Batching** | ✅ | ✅ | - | Comprehensive |
| **Persistence** | ✅ | ✅ | - | Comprehensive |
| **Privacy** | ✅ | - | - | Comprehensive |
| **Configuration** | ✅ | - | - | Comprehensive |
| **URL Exclusion** | ✅ | - | ✅ | Comprehensive |
| **Extras Merging** | ✅ | - | ✅ | Comprehensive |
| **Error Handling** | ✅ | - | - | Comprehensive |

## Best Practices

### When to Write Unit Tests
- Testing component logic
- Testing error handling
- Testing edge cases
- Testing calculations and transformations
- Fast feedback needed

### When to Write Integration Tests
- Testing disk persistence
- Testing crash recovery
- Testing component interaction with real dependencies
- Verifying DataQueue/PersistentHitQueue behavior

### When to Write E2E Tests
- Testing user-facing flows
- Testing public API behavior
- Testing complete extension flow
- Verifying Edge event dispatch

## Test Quality Standards

All tests follow these standards:

✅ **Descriptive names**: `testAssetEvent_WithBatchingDisabled_DispatchesImmediately`  
✅ **Clear assertions**: Specific error messages  
✅ **Proper setup/teardown**: Use base classes  
✅ **No flaky tests**: Reliable, deterministic  
✅ **Fast execution**: Unit tests < 10ms  
✅ **Isolated**: No shared state between tests  
✅ **Documented**: Comments explain "why", not "what"

## Debugging Tests

### Unit Test Failures
1. Check mock setup
2. Verify test data
3. Check assertions
4. Review recent code changes

### Integration Test Failures
1. Check disk permissions
2. Verify DataQueue creation
3. Increase wait timeouts
4. Check test directory cleanup

### E2E Test Failures
1. Check event names (must use `TRACK_*`)
2. Verify configuration setup
3. Increase async wait times
4. Check XDM payload structure
5. Verify listener registration

## Performance Benchmarks

| Operation | Unit Test | Integration Test | E2E Test |
|-----------|-----------|------------------|----------|
| **Setup** | < 1ms | ~100ms | ~500ms |
| **Execution** | < 1ms | ~500ms-2s | ~1-2s |
| **Teardown** | < 1ms | ~50ms | ~100ms |
| **Total** | ~1ms | ~0.6-3s | ~1.5-2.5s |

## Continuous Integration

Tests are designed to run reliably in CI environments:

- ✅ No external dependencies
- ✅ No network calls
- ✅ Deterministic results
- ✅ Fast execution (~37s total)
- ✅ Clear failure messages
- ✅ Automatic cleanup

## Adding New Tests

1. **Determine test type**:
   - Logic/calculations → Unit test
   - Disk persistence → Integration test
   - User-facing flow → E2E test

2. **Use existing patterns**:
   - Inherit from appropriate base class
   - Use helper methods
   - Follow naming conventions

3. **Ensure quality**:
   - Descriptive name
   - Clear assertions
   - Proper cleanup
   - No flakiness

## Future Enhancements

Potential additions:
- Performance benchmarks
- Memory leak detection
- Thread safety tests
- Stress tests (high volume)
- Network failure simulation
- Privacy flow tests
- Lifecycle event tests

## FAQs

**Why 300 tests?**  
Comprehensive coverage of all components, features, and edge cases.

**Are tests too slow?**  
No. 37s for 300 tests is excellent. Unit tests are fast (~1ms), integration/E2E tests are appropriately slower due to real I/O.

**Why separate Unit/Integration/E2E?**  
Different testing goals and speeds. Unit tests for fast feedback, integration for real dependencies, E2E for user flows.

**Can I run tests in parallel?**  
Yes, but some integration tests may conflict if they use the same disk locations. Unit tests are fully parallelizable.

**How do I add a new test?**  
See the appropriate README (Unit/Integration/E2E) for patterns and examples.
