# Release Notes

## 5.0.3 (June 9, 2026)

### Bug Fixes
- **Featurization definition state:** Experience definitions are now marked as sent to the featurization service only after the hit is accepted by the queue. Previously the state was flipped unconditionally, so failures (missing datastream, consent denied, encode failures) silently prevented retries within the session.
- **`edge.configId` fallback:** When `contentanalytics.configId` is not present in the Launch configuration, the extension now falls back to `edge.configId` for the featurization datastream, matching the documented behavior.
- **Runtime configuration validation:** Remote configurations are now validated after decode. Validation issues are logged, and `maxBatchSize` values outside the supported range are clamped to safe bounds instead of being accepted silently.
- **Default configuration after identity reset:** `ConfigurationManager.reset()` now restores the default configuration instead of leaving it `nil`, so tracking continues to function until a new Configuration shared state arrives.

---

## 5.0.2 (May 4, 2026)

### Features
- **Exclude assets from untracked experiences:** New configuration flag `excludeAssetsFromUntrackedExperience` — when enabled, asset events belonging to excluded experiences are suppressed, preventing orphaned asset tracking.

---

## 5.0.1 (February 23, 2026)

### Bug Fixes
- **Batching configuration alignment:** `batchFlushInterval` and `maxWaitTime` now use milliseconds  matching the Launch extension. Use `2000` for 2 seconds (was previously seconds ).

---

## 5.0.0 (February 9, 2026)

### General Availability

First stable release. Includes all features from 5.0.0-beta.1.

---

## 5.0.0-beta.1 (January 26, 2026)

### Initial Beta Release

> **⚠️ Beta Release:** This is a beta version intended for early testing with select customers. 
> Not recommended for production use. Please report any issues on GitHub.

### Initial Release

**Features**
- Asset tracking (views and clicks) for images and media
- Experience tracking for complex UI components
- Automatic event batching with configurable parameters
- Edge Network integration for data transmission
- Privacy-compliant tracking with consent management
- Crash-resistant delivery using PersistentHitQueue
- ML model featurization support (optional)
- Exclusion patterns for URL and experience filtering
- Comprehensive test coverage (99%+)

**Platforms**
- iOS 15.0+
- tvOS 15.0+

**Dependencies**
- AEPCore 5.0.0+
- AEPServices 5.0.0+
- AEPEdge 5.0.0+
- AEPEdgeIdentity 5.0.0+

**Documentation**
- Getting Started guide
- Complete API reference (Swift & Objective-C)
- Advanced configuration guide
- Troubleshooting guide
- Sample application

---

## Development Releases

Development versions are available but not recommended for production use.

---

For detailed information about each release, see [Releases](https://github.com/adobe/aca-mobile-sdk-ios-extension/releases).
