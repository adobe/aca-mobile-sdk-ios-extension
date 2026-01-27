# Advanced Configuration

Advanced configuration and customization options for the Content Analytics extension.

## Table of Contents

- [Event Batching](#event-batching)
- [Content Filtering](#content-filtering)
- [Privacy and Consent](#privacy-and-consent)
- [ML Featurization](#ml-featurization)
- [Custom Data](#custom-data)
- [Performance Tuning](#performance-tuning)
- [Debugging](#debugging)

---

## Datastream Configuration

### Separate Datastream for Content Analytics

Content Analytics events can be sent to a **different datastream** than your regular app events. This is useful for:
- Isolating Content Analytics data processing
- Different data governance requirements
- Separate datastreams for different purposes

**Configuration in Adobe Launch:**

```json
{
  "edge.configId": "main-app-datastream-id",
  "contentanalytics.configId": "content-analytics-datastream-id"
}
```

**Behavior:**
- When `contentanalytics.configId` is configured, all Content Analytics events use that datastream
- Regular app events (e.g., commerce, page views) continue using `edge.configId`
- If `contentanalytics.configId` is not set, Content Analytics events use the default `edge.configId`

**Programmatic Configuration:**

```swift
MobileCore.updateConfigurationWith(configDict: [
    "edge.configId": "main-app-datastream-id",
    "contentanalytics.configId": "content-analytics-datastream-id"
])
```

### Single Datastream (Default)

If you don't need a separate datastream, omit the override:

```json
{
  "edge.configId": "unified-datastream-id"
}
```

All events (regular and Content Analytics) will use the same datastream. You can still route them to different datasets using datastream event type rules in Adobe Experience Platform.

**Note:** The sandbox for Content Analytics events is determined by the datastream configuration itself in Adobe Experience Platform. The datastream is created in a specific sandbox, and all events using that datastream will automatically route to that sandbox's datasets.

---

## Event Batching

The extension batches events for better performance and network efficiency.

### Configuration

Configure in Adobe Data Collection UI:

```json
{
  "contentanalytics.config": {
    "batchingEnabled": true,
    "maxBatchSize": 10,
    "flushInterval": 2.0
  }
}
```

### Batching Behavior

Events are batched based on `maxBatchSize` and `flushInterval`. Batches flush when:
- Batch reaches `maxBatchSize`
- `flushInterval` (seconds) has elapsed
- App moves to background

Events persist to disk and survive app restarts.

### Disabling Batching

Send events immediately:

```json
{
  "contentanalytics.config": {
    "batchingEnabled": false
  }
}
```

---

## Content Filtering

Exclude specific content from tracking using filters.

### Asset URL Regex

Exclude assets by URL using a single regex pattern (use `|` for multiple patterns):

```json
{
  "contentanalytics.config": {
    "excludedAssetUrlsRegexp": ".*\\.gif$|^https://cdn\\.test\\..*|.*/internal/.*"
  }
}
```

**Examples:**
- `".*\\.gif$"` - Exclude all GIFs
- `"^https://cdn\\.test\\..*"` - Exclude test CDN
- `".*\\.gif$|.*\\.svg$"` - Exclude GIFs and SVGs (multiple patterns)

### Asset Locations

Exclude assets by exact location match:

```json
{
  "contentanalytics.config": {
    "excludedAssetLocations": ["debug", "test", "internal"]
  }
}
```

**Behavior:**
- Exact string match (not regex)
- Case-sensitive
- Assets without location are not affected

### Experience Locations

Exclude experiences by location (exact match or regex):

```json
{
  "contentanalytics.config": {
    "excludedExperienceLocations": ["admin", "settings"],
    "excludedExperienceLocationsRegexp": "^test\\..*|.*\\.debug$"
  }
}
```

**Filtering Logic:**
1. Check exact match in `excludedExperienceLocations`
2. Check regex pattern in `excludedExperienceLocationsRegexp`
3. If either matches, experience is excluded

### Use Cases

**Development/Testing:**
```json
{
  "excludedAssetLocations": ["dev", "staging"],
  "excludedExperienceLocationsRegexp": "^test\\..*"
}
```

**Performance Optimization:**
```json
{
  "excludedAssetUrlsRegexp": ".*\\.svg$|.*thumb.*"
}
```

**Privacy/Compliance:**
```json
{
  "excludedExperienceLocations": ["user.profile", "account.settings"]
}
```

---

## Privacy and Consent

### Privacy Status

Control tracking:

```swift
MobileCore.setPrivacyStatus(.optedIn)  // tracking enabled
MobileCore.setPrivacyStatus(.optedOut)  // tracking disabled
MobileCore.setPrivacyStatus(.optUnknown)  // tracking disabled
```

### Edge Consent

For Edge Network consent:

```swift
import AEPEdgeConsent

let consents = ["consents": [
    "collect": ["val": "y"]
]]

Consent.update(with: consents)
```

The extension respects both `MobileCore.setPrivacyStatus()` (legacy) and Edge Consent (recommended).

---

## ML Featurization

Send experience data to an ML featurization service for metadata extraction.

### Configuration

Set the service URL in Adobe Data Collection:

```json
{
  "contentanalytics.config": {
    "featurizationServiceUrl": "https://your-service.example.com"
  }
}
```

### Behavior

When configured:
- Experience registrations sent to featurization service
- Service extracts metadata (colors, objects, text sentiment, etc.)
- Requests persisted and retried automatically
- 100% delivery guarantee via persistent queue

### Featurization Payload

The service receives:

```json
{
  "experienceId": "mobile-abc123...",
  "orgID": "YOUR_ORG@AdobeOrg",
  "channel": "mobile",
  "content": {
    "images": [
      {"value": "https://example.com/image.jpg", "style": {"location": "hero"}}
    ],
    "texts": [
      {"value": "Product Title", "style": {"role": "headline"}}
    ],
    "ctas": [
      {"value": "Buy Now", "style": {"enabled": true}}
    ]
  }
}
```

---

## Custom Data

Add custom data using `additionalData`:

### Experience Tracking

```swift
// On registration
let expId = ContentAnalytics.registerExperience(
    assetURLs: [...],
    texts: [...],
    ctas: [...],
    experienceLocation: "product.detail",
    additionalData: [
        "sku": "12345",
        "category": "electronics"
    ]
)

// On interaction
ContentAnalytics.trackExperienceView(
    experienceId: expId,
    additionalData: [
        "viewDuration": 5.2,
        "scrollDepth": 0.75
    ]
)

ContentAnalytics.trackExperienceClick(
    experienceId: expId,
    additionalData: [
        "element": "addToCart",
        "price": 999.99
    ]
)
```

Custom data appears in the XDM payload under `experienceExtras`.

---

## Performance Tuning

### Batch Size

Larger batches = fewer network requests but higher latency:

```json
{
  "maxBatchSize": 20,  // Send every 20 events
  "flushInterval": 5.0  // or every 5 seconds
}
```

**Recommendations:**
- High-frequency apps (gaming, social): 20-50
- Low-frequency apps (ecommerce): 5-10
- Real-time requirements: disable batching

### Memory Management

Minimal memory usage:
- Metrics stored in-memory (< 1KB per asset/experience)
- Events persisted to disk immediately
- No large caches or buffers

### Network Efficiency

- Batching reduces requests by 10-100x
- Persistent queue ensures delivery without retry loops
- Automatic backoff on failures

---

## Debugging

### Enable Debug Logging

In Adobe Data Collection:

```json
{
  "contentanalytics.config": {
    "debugLogging": true
  }
}
```

Or programmatically:

```swift
MobileCore.setLogLevel(.trace)  // most verbose
MobileCore.setLogLevel(.debug)  // recommended
```

### Log Output

Log prefixes:
- `[ContentAnalytics]` - Main extension
- `[ContentAnalytics.Orchestrator]` - Event processing
- `[ContentAnalytics.Batch]` - Batching
- `[ContentAnalytics.Featurization]` - ML service

### Common Patterns

Event flow:
```
[ContentAnalytics] Asset view tracked | URL: .../hero.jpg | Location: home.hero
[ContentAnalytics.Orchestrator] Metrics updated | Asset: mobile-abc123
[ContentAnalytics.Batch] Batch complete (10 events) | Dispatching to Edge
```

Featurization:
```
[ContentAnalytics.Featurization] Experience queued | ID: mobile-xyz789
[ContentAnalytics.Featurization] Featurization registered | ID: mobile-xyz789
```

See [Troubleshooting Guide](troubleshooting.md) for common issues.

---

## Next Steps

- [API Reference](api-reference.md)
- [Troubleshooting](troubleshooting.md)
- [Sample App](../SampleApps/AEPContentAnalyticsDemo)

