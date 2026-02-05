# Advanced Configuration

## Configuration Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `contentanalytics.configId` | String | - | Datastream override |
| `contentanalytics.trackExperiences` | Bool | `true` | Enable experience tracking |
| `contentanalytics.batchingEnabled` | Bool | `true` | Enable batching |
| `contentanalytics.maxBatchSize` | Int | `10` | Events before flush (1-100) |
| `contentanalytics.batchFlushInterval` | Double | `2.0` | Seconds between flushes |
| `contentanalytics.excludedAssetUrlsRegexp` | String | - | Exclude assets by URL |
| `contentanalytics.excludedAssetLocationsRegexp` | String | - | Exclude assets by location |
| `contentanalytics.excludedExperienceLocationsRegexp` | String | - | Exclude experiences by location |

**Set via Launch UI** or programmatically:

```swift
MobileCore.updateConfigurationWith(configDict: [
    "contentanalytics.maxBatchSize": 20,
    "contentanalytics.batchFlushInterval": 5.0
])
```

---

## Datastream

### Separate Datastream

Route Content Analytics to a different datastream:

```json
{
  "edge.configId": "main-datastream-id",
  "contentanalytics.configId": "content-analytics-datastream-id"
}
```

If `contentanalytics.configId` is not set, uses `edge.configId`.

---

## Batching

Flush triggers:
- Batch reaches `maxBatchSize`
- Timer reaches `batchFlushInterval`
- App backgrounds

```json
{
  "contentanalytics.batchingEnabled": true,
  "contentanalytics.maxBatchSize": 10,
  "contentanalytics.batchFlushInterval": 2.0
}
```

Disable for immediate sends:

```json
{ "contentanalytics.batchingEnabled": false }
```

> **Note:** Batching only affects network delivery. Features like asset attribution, experience tracking, and featurization work the same whether batching is enabled or disabled.

---

## Filtering

### By URL

```json
{ "contentanalytics.excludedAssetUrlsRegexp": ".*\\.gif$|.*spinner.*" }
```

### By Location

```json
{ "contentanalytics.excludedAssetLocationsRegexp": "^(debug|test).*" }
{ "contentanalytics.excludedExperienceLocationsRegexp": "^admin\\..*" }
```

---

## Privacy

### Edge Consent

```swift
// Opt in
Consent.update(with: ["consents": ["collect": ["val": "y"]]])

// Opt out
Consent.update(with: ["consents": ["collect": ["val": "n"]]])

// Pending
Consent.update(with: ["consents": ["collect": ["val": "p"]]])
```

| Value | Result |
|-------|--------|
| `"y"` | Events sent |
| `"n"` | Events dropped |
| `"p"` | Events queued |

### Legacy

```swift
MobileCore.setPrivacyStatus(.optedIn)   // send
MobileCore.setPrivacyStatus(.optedOut)  // drop + clear
MobileCore.setPrivacyStatus(.unknown)   // queue
```

### Data Deletion

```swift
MobileCore.resetIdentities()  // clears cache + queue
```

---

## Featurization

Configured automatically. Sends experience content to ML service for feature extraction.

Payload sent:

```json
{
  "experienceId": "mobile-abc123",
  "orgID": "YOUR_ORG@AdobeOrg",
  "content": {
    "images": [{"value": "https://...jpg", "style": {}}],
    "texts": [{"value": "Title", "style": {"role": "headline"}}],
    "ctas": [{"value": "Buy", "style": {"enabled": true}}]
  }
}
```

---

## Tuning Batch Settings

The default settings (`maxBatchSize: 10`, `flushInterval: 2s`) work well for most apps. Adjust based on your event volume:

| Events per Minute | maxBatchSize | flushInterval | Notes |
|-------------------|--------------|---------------|-------|
| < 10 | 10 (default) | 2s (default) | Default works well |
| 10-50 | 15-25 | 3s | Reduces network calls |
| > 50 | 25-50 | 5s | High-volume optimization |

**Trade-off:** Larger batches reduce network overhead but increase latency before data appears in reporting.

---

## Debugging

```swift
MobileCore.setLogLevel(.debug)
```

Log tags:
- `[ContentAnalytics]` - main
- `[ContentAnalytics.Batch]` - batching
- `[ContentAnalytics.Featurization]` - ML service

---

## See Also

- [API Reference](api-reference.md)
- [Experience Tracking](EXPERIENCE_TRACKING_GUIDE.md)
- [Troubleshooting](troubleshooting.md)
