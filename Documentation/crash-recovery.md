# Crash Recovery

## How It Works

Events persist to disk immediately via `PersistentHitQueue`. Zero data loss.

## Architecture

```
User views asset
  └─> Event → PersistentQueue (disk) ✓ crash-safe

Timer fires (2s) or 10 events reached
  ├─> Flush notification sent
  └─> BatchHitProcessor reads events from queue
      ├─> Groups by asset/experience
      ├─> Calculates metrics (views, clicks) from events
      └─> Dispatches to Edge Network

Queue cleaned after successful dispatch
```

## Components

### BatchProcessor
- Persists incoming events to `PersistentQueue` immediately
- Counts events for batch threshold (10 events or 2s timer)
- Posts flush notification when threshold met

### BatchHitProcessor  
- Decodes events from `PersistentQueue`
- On flush: groups events by asset/experience
- Calculates metrics on-the-fly from event list
- Dispatches single Edge event per batch containing all assets/experiences

### PersistentQueue
- Two queues: `asset.batch` and `experience.batch`
- Events encoded as JSON via `Event.Codable`
- Survives crashes, app restarts, background termination

## Example Timeline

```
10:00:00 - View Asset A     → queued
10:00:01 - Click Asset B    → queued
10:00:02 - Click Asset B    → queued
...
10:00:10 - Click Asset B    → queued (10th event)
[Batch threshold reached]
  └─> Read 10 events from queue
  └─> Calculate: Asset A (1 view), Asset B (9 clicks)
  └─> Dispatch 1 Edge event with both assets
  └─> Clear queue after successful dispatch
```

## Crash Scenarios

### Before Flush (0-2s window)
```
Status: Events in PersistentQueue
Recovery: Next launch processes queued events
Result: Zero data loss
```

### During Flush (processing batch)
```
Status: Events in queue, batch being processed
Recovery: Queue retains events until confirmed dispatch
Result: Zero data loss (may see duplicate dispatch if crash mid-send)
```

### After Dispatch
```
Status: Queue cleared, events sent to Edge
Recovery: Edge handles network retries via its own queue
Result: Normal flow
```

## Edge Network Handoff

After we dispatch to Edge, their infrastructure handles:
- Network failures and retries
- Exponential backoff
- Server errors

We only clear our queue after Edge accepts the event.

## Metrics Calculation

Metrics are **not persisted separately**. They're derived from events:

```swift
// On flush
let events = readEventsFromQueue()
let viewCount = events.filter { $0.interactionType == .view }.count
let clickCount = events.filter { $0.interactionType == .click }.count

// Dispatch with calculated metrics
dispatch(assetURL: url, views: viewCount, clicks: clickCount)
```

This eliminates state synchronization issues.

## Data Loss Windows

**None.** 

Events persist before any processing. Crash at any point is recoverable from queue.

## Configuration

```json
{
  "contentanalytics.batchingEnabled": true,
  "contentanalytics.maxBatchSize": 10,
  "contentanalytics.flushInterval": 2.0
}
```

Set `batchingEnabled: false` to bypass batching (immediate dispatch).

## Performance Notes

- Disk I/O per event (~1ms)
- Batching reduces Edge traffic by 10x
- Memory usage minimal (no in-memory metrics state)

## Testing Crash Recovery

1. Track 5 events
2. Force-quit app (don't wait for flush)
3. Relaunch app
4. Track 5 more events
5. Wait for flush (2s)
6. Verify: 10 events in single batch sent to Edge

## Comparison with Edge Extension

**Edge Extension**: Events persist → dispatch individually  
**Content Analytics**: Events persist → batch by asset → dispatch once per batch

Both use `PersistentHitQueue`. Our batching reduces network overhead for high-volume tracking.
