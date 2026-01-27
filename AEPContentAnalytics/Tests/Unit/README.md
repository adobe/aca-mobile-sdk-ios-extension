# Unit Tests

Tests individual components in isolation with mocked dependencies.

## Test Files

### ContentAnalyticsPublicAPITests (14 tests)
Public-facing API methods:
- Asset tracking API
- Experience registration API
- Experience tracking API
- Configuration API
- Reset and flush APIs

### MetricsManagerTests (12 tests)
Metrics aggregation and persistence:
- Asset metrics counting
- Experience metrics counting
- Metrics accumulation
- Metrics reset

### XDMEventBuilderTests (15 tests)
XDM payload generation:
- Asset XDM structure
- Experience definition events
- Experience interaction events
- Asset attribution

### ContentAnalyticsOrchestratorTests (12 tests)
Event orchestration:
- Event processing
- Validation logic
- Batch processing
- Privacy handling

### ContentAnalyticsStateManagerTests (13 tests)
State management:
- Configuration updates
- Experience caching
- Shared state
- Thread safety

### ContentAnalyticsExclusionTests (30 tests)
Exclusion pattern functionality:
- URL pattern exclusion (exact, wildcards, regex)
- Experience location pattern exclusion
- Multiple patterns and case handling
- Integration with event processing
- Performance tests

## Total: 91 Unit Tests

## Running

```bash
# All unit tests
xcodebuild test -only-testing:ContentAnalyticsTests/Unit

# Specific file
xcodebuild test -only-testing:ContentAnalyticsTests/ContentAnalyticsPublicAPITests
```

## Characteristics
- Fast execution (< 2 seconds total)
- No external dependencies
- Mocked components
- Isolated test cases
- Deterministic results
