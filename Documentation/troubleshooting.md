# Troubleshooting

Common issues and solutions for the Content Analytics extension.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Issues](#configuration-issues)
- [Tracking Issues](#tracking-issues)
- [Network Issues](#network-issues)
- [Debugging](#debugging)

---

## Installation Issues

### Swift Package Manager: "No such module 'AEPContentAnalytics'"

Package not properly resolved. Try:
1. Clean build folder (**Product > Clean Build Folder** or ⇧⌘K)
2. Reset package cache (**File > Packages > Reset Package Caches**)
3. Rebuild
4. Check your import: `import AEPContentAnalytics`

### CocoaPods: "Unable to find a specification for AEPContentAnalytics"

Update your CocoaPods cache:

```bash
pod repo update
pod install --repo-update
```

---

## Configuration Issues

### "Extension not registered"

You'll see:
```
[AEPCore] Extension 'ContentAnalytics' is not registered
```

Register the extension before making tracking calls:

```swift
MobileCore.registerExtensions([
    Edge.self,
    ContentAnalytics.self
]) {
    print("Extensions registered")
}
```

### "Configuration not available"

No events sent to Edge or logs show "Configuration unavailable".

Fix:
1. Verify your Launch Environment File ID in `MobileCore.configureWith(appId: "...")`
2. Check that your Launch configuration is published
3. Verify network connectivity
4. Give the config time to load (it's async)

---

## Tracking Issues

### Events not appearing in AEP

**Checklist:**

1. **Privacy Status**
   ```swift
   // Verify user has opted in
   MobileCore.setPrivacyStatus(.optedIn)
   ```

2. **Edge Extension**
   ```swift
   // Edge must be registered for data delivery
   MobileCore.registerExtensions([Edge.self, ContentAnalytics.self])
   ```

3. **Datastream Configuration**
   - Verify datastream is configured in Adobe Data Collection
   - Check datastream is enabled
   - Verify services are mapped correctly

4. **Debug Logging**
   ```swift
   MobileCore.setLogLevel(.debug)
   ```
   Look for:
   ```
   [ContentAnalytics] 📊 Asset view tracked
   [Edge] Sending event to Edge Network
   ```

### Experience ID is always different

**Expected Behavior:** Experience IDs are deterministic based on content.

**Formula:**
```
experienceID = "mobile-" + SHA1([...images, ...texts, ...ctas])
```

**Troubleshooting:**
- Ensure content arrays are identical for same experience
- Order matters: `["A", "B"]` ≠ `["B", "A"]`
- Whitespace matters: `"Hello"` ≠ `"Hello "`

**Solution:**
```swift
// Use consistent content
let texts = ["Title", "Subtitle"].sorted()
let images = ["url1", "url2"].sorted()

let expId = ContentAnalytics.registerExperience(
    assetURLs: images,
    texts: texts.map { ExperienceTextContent(text: $0) },
    ...
)
```

### Asset views not incrementing

The extension deduplicates rapid repeated events (< 100ms) to prevent double-counting from view lifecycle methods. This is intentional.

If you need to track multiple views intentionally, add a delay:

```swift
ContentAnalytics.trackAssetView(assetURL: url, assetLocation: "gallery")

// Wait > 100ms before tracking again
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    ContentAnalytics.trackAssetView(assetURL: url, assetLocation: "gallery")
}
```

---

## Network Issues

### Featurization requests failing

**Symptoms:**
```
[ContentAnalytics.Featurization] ⚠️ Recoverable error (503)
```

**Solution:**
This is normal for temporary outages. The extension retries automatically with exponential backoff. Requests persist to disk and survive app restarts.

**If persistent (> 24 hours):**
1. Verify `featurizationServiceUrl` is correct
2. Check service health status
3. Review service logs for errors

### "No response from featurization service"

**Cause:** Service URL not configured or unreachable.

**Solution:**
1. Configure in Adobe Data Collection:
   ```json
   {
     "featurizationServiceUrl": "https://your-service.example.com"
   }
   ```
2. Verify URL is accessible from device
3. Check network permissions in Info.plist:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsArbitraryLoads</key>
       <true/>
   </dict>
   ```

---

## Debugging

### Enable Verbose Logging

**Option 1: Adobe Data Collection**
```json
{
  "contentanalytics.config": {
    "debugLogging": true
  }
}
```

**Option 2: Programmatically**
```swift
MobileCore.setLogLevel(.trace)  // Most verbose
```

### Inspect Event Flow

Enable logging and look for this sequence:

```
1. [ContentAnalytics] 📊 Asset view tracked | URL: ...
2. [ContentAnalytics.Orchestrator] ✅ Metrics updated
3. [ContentAnalytics.Batch] 📦 Batch complete (10 events)
4. [Edge] Sending event to Edge Network
5. [Edge] Event sent successfully
```

If flow breaks, note where it stops.

### Common Log Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `⏭️ Skipping - privacy not opted in` | User opted out | Check privacy status |
| `⏭️ Skipping - invalid asset URL` | Malformed URL | Validate URL format |
| `⚠️ Configuration not loaded` | Config unavailable | Wait or check Launch setup |
| `✅ Event dispatched` | Event sent successfully | No action needed |
| `❌ Failed to encode` | Data encoding error | Report issue with payload |

### Inspect Shared State

To debug configuration issues:

```swift
let configState = MobileCore.getSharedState(
    extensionName: "com.adobe.module.configuration",
    event: nil,
    barrier: false
)
print("Config: \(configState ?? [:])")
```

### Use Assurance (Project Griffon)

Adobe Experience Platform Assurance provides real-time debugging:

1. Install AEPAssurance extension
2. Connect device to Assurance session
3. View events in real-time
4. Inspect payloads and state

---

## Getting Help

If you're still experiencing issues:

1. **Check GitHub Issues:** [Known Issues](https://github.com/adobe/aca-mobile-sdk-ios-extension/issues)
2. **Search Discussions:** [GitHub Discussions](https://github.com/adobe/aca-mobile-sdk-ios-extension/discussions)
3. **File a Bug Report:**
   - Include SDK version
   - Include relevant logs
   - Include minimal reproduction steps
   - Include device/OS version

---

## Additional Resources

- [Getting Started](getting-started.md)
- [API Reference](api-reference.md)
- [Advanced Configuration](advanced-configuration.md)

