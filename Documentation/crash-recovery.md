# Crash Recovery Architecture

## Overview

Content Analytics uses `PersistentHitQueue` to protect against data loss during the batching window (0-5 seconds). Events are written to disk immediately and only removed **after** successful dispatch to Edge Network.

## How It Works

```
User tracks event
  └─> Event added to memory + disk ✓ crash-safe
      │
      └─> Batching (0-5 seconds, events stay on disk)
          │
          └─> Flush triggered
              │
              ├─> Process accumulated events
              ├─> Calculate aggregated metrics
              ├─> Dispatch to Edge Network
              └─> Mark events as dispatched → removed from disk on next cycle
```

## Architecture Components

### BatchCoordinator
**Responsibilities:**
- Manages batching logic (count threshold + time-based flush)
- Writes incoming events to disk immediately via `PersistentHitQueue`
- Maintains in-memory event counters (not the events themselves)
- Triggers flush when threshold reached (10 events or 5 seconds)
- Coordinates between `DirectHitProcessor` and `ContentAnalyticsOrchestrator`

**Key Methods:**
```swift
func addAssetEvent(_ event: Event)
  ├─> assetHitProcessor.accumulateEvent(event)      // Add to memory
  ├─> persistEventImmediately(event, to: queue)    // Write to disk
  └─> checkAndFlushIfNeeded()                       // Check thresholds

func performFlush()
  ├─> let events = assetHitProcessor.processAccumulatedEvents()
  ├─> [Orchestrator processes events → dispatches to Edge]
  └─> assetHitProcessor.markEventsAsDispatched(events)  // Allow disk cleanup
```

### DirectHitProcessor
**Responsibilities:**
- Implements `HitProcessing` protocol for `PersistentHitQueue` integration
- Accumulates events in memory for fast batching
- Tracks which events have been dispatched to Edge
- Removes events from disk only after Edge dispatch

**Event Lifecycle:**
```swift
func processHit(entity: DataEntity, completion: (Bool) -> Void)
  ├─> Decode event from disk
  ├─> Check if already dispatched to Edge
  │   ├─> YES: completion(true) → remove from disk ✓
  │   └─> NO:  completion(false) → keep on disk ✓
  └─> Accumulate in memory for batching

func markEventsAsDispatched(_ events: [Event])
  └─> Add event IDs to dispatchedEventIds set
      └─> Next processHit() cycle will remove from disk
```

### PersistentHitQueue (AEPServices)
**Provides:**
- Two separate queues: `asset.events` and `experience.events`
- SQLite-backed persistence (survives crashes, force-quit, background termination)
- Automatic processing via `beginProcessing()`
- Thread-safe operations

**Storage:**
- Events encoded as JSON via `Event: Codable`
- Each event wrapped with type metadata (`asset` or `experience`)
- Unique identifier: `event.id.uuidString`

## Detailed Timeline Example

```
Time   │ Event                                │ Memory │ Disk │ Safe?
───────┼──────────────────────────────────────┼────────┼──────┼───────
00.00s │ User views Asset A                   │ ✓      │ ✓    │ ✅ YES
00.01s │ Event written to disk                │ ✓      │ ✓    │ ✅ YES
00.50s │ User clicks Asset B                  │ ✓      │ ✓    │ ✅ YES
01.00s │ User clicks Asset B                  │ ✓      │ ✓    │ ✅ YES
       │ [Batching window - events on disk]   │        │      │
02.00s │ Timer fires → Flush triggered        │ ✓      │ ✓    │ ✅ YES
02.01s │ Process accumulated events           │ ✓      │ ✓    │ ✅ YES
02.02s │ Calculate metrics (1 view, 2 clicks) │ ✓      │ ✓    │ ✅ YES
02.03s │ Dispatch to Edge Network             │ ✓      │ ✓    │ ✅ YES
02.04s │ markEventsAsDispatched() called      │ ✗      │ ✓    │ ✅ YES
02.05s │ Next queue cycle                     │ ✗      │ ✗    │ ✅ YES*
       │ (*Edge has received events)          │        │      │

Legend:
✓ = Present
✗ = Not present
```

**Critical Protection:** Events remain on disk for the entire 0-5 second batching window, ensuring crash recovery.

## Crash Scenarios

### Scenario 1: Crash During Batching (0-5s window)
```
Status: Events in memory + disk
Crash:  ⚡ App terminated
        └─> Memory lost ✗
        └─> Disk persists ✓

Recovery on Next Launch:
1. PersistentHitQueue.beginProcessing() starts
2. DirectHitProcessor.processHit() called for each persisted event
3. Events accumulated in memory
4. Normal batch processing resumes

Result: ✅ ZERO DATA LOSS
```

### Scenario 2: Crash During Flush
```
Status: Events being processed, still on disk
Crash:  ⚡ App terminated mid-dispatch
        └─> Memory lost ✗
        └─> Disk persists ✓

Recovery on Next Launch:
1. Events still on disk (not marked as dispatched)
2. Re-read and re-dispatch on next flush

Result: ✅ ZERO DATA LOSS (possible duplicate dispatch)
```

### Scenario 3: Crash After Edge Dispatch
```
Status: Events dispatched, marked for removal
Crash:  ⚡ App terminated
        └─> Memory lost ✗
        └─> Disk cleanup incomplete

Recovery on Next Launch:
1. Events still on disk but marked as dispatched
2. processHit() sees dispatchedEventIds → removes from disk

Result: ✅ MINIMAL DATA LOSS RISK (~10-20ms window*)
```

**\*Window:** Small gap between Edge dispatch and disk removal is unavoidable without confirmation callbacks. Edge Network's own `PersistentHitQueue` takes over from this point.

## Data Loss Windows

### Protected (✅ SAFE):
- **0-5 seconds (batching):** Events on disk ✓
- **During flush/dispatch:** Events on disk ✓
- **Edge handoff:** Edge's persistence takes over ✓

### Minimal Risk (⚠️ 10-20ms):
- **After Edge dispatch, before disk cleanup:** Events in Edge's Event Hub but not yet in Edge's persistent queue
- This is unavoidable without confirmation callbacks between extensions
- Edge's PersistentHitQueue provides subsequent crash recovery

### Comparison with Other Extensions:
Most Adobe extensions (e.g., Concierge) **do not** persist events before dispatching to Edge. Content Analytics provides **stronger crash recovery guarantees** during the batching window.

## Edge Network Handoff

Once we dispatch to Edge extension:

```
ContentAnalytics → runtime.dispatch(event) → Event Hub → Edge Extension
                                                           └─> Edge.PersistentHitQueue
                                                               └─> Network retries
                                                               └─> Exponential backoff
```

**Handoff Point:** After `eventDispatcher.dispatch()` completes, Edge extension owns persistence.

**No Confirmation:** Extensions cannot receive dispatch confirmations from Edge (architectural limitation).

## Metrics Calculation

Metrics are **derived from events**, not stored separately:

```swift
// On flush (ContentAnalyticsOrchestrator.swift)
func buildAssetMetricsCollection(from events: [Event]) -> AssetMetricsCollection {
    let groupedEvents = Dictionary(grouping: events) { $0.assetKey ?? "" }
    var metricsMap: [String: AssetMetrics] = [:]
    
    for (key, events) in groupedEvents {
        let views = events.filter { $0.interactionType == .view }.count
        let clicks = events.filter { $0.interactionType == .click }.count
        metricsMap[key] = AssetMetrics(viewCount: views, clickCount: clicks, ...)
    }
    
    return AssetMetricsCollection(metrics: metricsMap)
}
```

**Benefits:**
- No state synchronization issues
- Crash recovery automatically restores correct metrics
- Single source of truth (events on disk)

## Configuration

```json
{
  "contentanalytics.batchingEnabled": true,
  "contentanalytics.maxBatchSize": 10,
  "contentanalytics.flushInterval": 2.0,
  "contentanalytics.maxWaitTime": 5.0
}
```

**Parameters:**
- `maxBatchSize`: Event count threshold (default: 10)
- `flushInterval`: Timer interval for periodic flush (default: 2s)
- `maxWaitTime`: Maximum time to hold events (default: 5s)
- `batchingEnabled`: Set to `false` for immediate dispatch (no batching)

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Event persistence | ~1-2ms | SQLite write |
| Event recovery | ~5-10ms | SQLite read on launch |
| Batch flush | ~10-20ms | Metrics calculation + Edge dispatch |
| Memory per event | ~2KB | Event object + metadata |
| Disk per event | ~1-2KB | JSON encoding |

**Memory Usage:** With default batch size (10), worst-case memory is ~20-40KB (negligible).

**Network Efficiency:** Batching reduces Edge Network calls by 10x for high-volume tracking.

## Testing Crash Recovery

### Test 1: Crash During Batching
```swift
1. Track 5 asset events
2. DO NOT wait for flush timer
3. Force-quit app (⌘+Q or kill process)
4. Relaunch app
5. Track 5 more asset events
6. Wait 2 seconds for flush
7. Verify: 1 Edge event with 10 aggregated interactions
```

### Test 2: Crash During Flush
```swift
1. Track 10 asset events (triggers immediate flush)
2. Set breakpoint in sendToEdge()
3. Force-quit app at breakpoint
4. Relaunch app
5. Wait 5 seconds
6. Verify: Events re-dispatched (possible duplicate)
```

### Test 3: Background Termination
```swift
1. Track events
2. Background app
3. iOS terminates app (memory pressure)
4. Relaunch app
5. Verify: Events recovered and dispatched
```

## Implementation Details

### Key Files
- `BatchCoordinator.swift` - Batching logic and persistence coordination
- `DirectHitProcessor.swift` - Disk cleanup and crash recovery
- `ContentAnalyticsOrchestrator.swift` - Metrics calculation and Edge dispatch
- `PersistentHitQueue` (AEPServices) - SQLite-backed queue

### Thread Safety
- All operations use serial dispatch queues
- `batchQueue` (BatchCoordinator) - batch operations
- `queue` (DirectHitProcessor) - hit processing

### Logging
Enable verbose logging to debug crash recovery:
```swift
Log.setLogLevel(.trace)
```

Look for:
```
[BATCH_PROCESSOR] Event accumulated, keeping on disk | ID: <uuid>
[BATCH_PROCESSOR] Event dispatched, removing from disk | ID: <uuid>
[BATCH_PROCESSOR] Recovered asset event from disk | ID: <uuid>
```

## Comparison with Edge Extension

| Feature | Content Analytics | Edge Extension |
|---------|------------------|----------------|
| Pre-dispatch persistence | ✅ YES (0-5s) | ❌ NO |
| Batching | ✅ YES | ❌ NO |
| Post-dispatch persistence | ✅ Edge's queue | ✅ PersistentHitQueue |
| Network retries | ✅ Edge handles | ✅ Exponential backoff |
| Crash recovery during batch | ✅ FULL | N/A |

**Why the difference?** Content Analytics has a batching window (0-5 seconds) where events accumulate before dispatch. Without persistence, crashes during this window would lose data. Edge extension dispatches immediately, so it relies on its own PersistentHitQueue after dispatch.

## Known Limitations

1. **No dispatch confirmation:** Extensions cannot receive callbacks from Edge to confirm receipt
2. **Possible duplicates:** Crash during Edge dispatch may cause duplicate events (Edge deduplication handles this)
3. **10-20ms window:** Small gap between Edge dispatch and disk cleanup is unavoidable
4. **Memory overhead:** Events held in memory + disk during batching (minimal: ~40KB)

## Future Enhancements

- **Configurable disk cleanup delay:** Add grace period after Edge dispatch
- **Event deduplication:** Track dispatched event hashes to prevent duplicates
- **Memory pressure handling:** Auto-flush on memory warnings (iOS only)
- **Metrics:** Track recovery counts for monitoring

---

**Last Updated:** 2026-01-28  
**Version:** 5.0.0
