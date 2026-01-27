# Stress & Performance Tests

Tests extension behavior under high load, concurrency, and extreme conditions.

## ContentAnalyticsStressTests (20 tests)

### Volume Tests
- 1,000 unique asset events
- 100 experiences with 300+ events
- 10,000 repeated views (same asset)

### Concurrency Tests
- 100 concurrent asset tracking calls
- 100 concurrent experience tracking calls
- 1,000 concurrent metrics updates (race condition detection)

### Memory Tests
- 5,000 unique assets (memory efficiency)
- Large experience payload (100 assets + 50 texts + 25 buttons)

### Burst Pattern Tests
- 10 bursts of 100 events (1,000 total)

### Edge Stress Tests
- Extremely long URLs (10KB each)
- 100 events with special characters
- 100 rapid configuration changes

### Performance Benchmarks
- Single asset tracking baseline
- 1,000 asset metrics aggregation
- Experience ID generation performance

## Running

```bash
xcodebuild test -only-testing:ContentAnalyticsTests/ContentAnalyticsStressTests
```

## Characteristics
- Execution time: ~15 seconds
- High volume (up to 10K events)
- Concurrent operations (up to 1K parallel)
- Memory stress testing
- Performance benchmarking

## Performance Targets
- Single event: < 1ms
- 1K events: < 100ms
- 10K events: < 1s
- No memory leaks
- No race conditions
- Thread-safe operations

## When to Run
- Before production releases
- After major refactoring
- To validate performance improvements
- CI/CD nightly builds
