# API Reference

Complete API reference for the AEP Content Analytics extension.

## Swift API

### Asset Tracking

#### trackAsset

Track asset interactions with explicit interaction type.

```swift
static func trackAsset(
    assetURL: String,
    interactionType: InteractionType = .view,
    assetLocation: String? = nil,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `assetURL`: Asset URL being tracked
- `interactionType`: `.view` or `.click` (default: `.view`)
- `assetLocation`: Optional semantic location (e.g., "home.hero", "product.gallery")
- `additionalData`: Optional custom data

**Example:**
```swift
// With default view
ContentAnalytics.trackAsset(
    assetURL: "https://example.com/hero.jpg",
    assetLocation: "home.hero"
)

// Explicit interaction type
ContentAnalytics.trackAsset(
    assetURL: "https://example.com/banner.jpg",
    interactionType: .click,
    assetLocation: "home.cta",
    additionalData: ["campaign": "summer-sale"]
)
```

---

#### trackAssetView

Convenience method for tracking asset views.

```swift
static func trackAssetView(
    assetURL: String,
    assetLocation: String? = nil,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `assetURL`: The URL of the asset being tracked
- `assetLocation`: (Optional) Semantic location identifier
- `additionalData`: (Optional) Additional custom data

**Example:**
```swift
ContentAnalytics.trackAssetView(
    assetURL: "https://example.com/hero.jpg",
    assetLocation: "home.hero"
)
```

---

#### trackAssetClick

Convenience method for tracking asset clicks.

```swift
static func trackAssetClick(
    assetURL: String,
    assetLocation: String? = nil,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `assetURL`: The URL of the asset being clicked
- `assetLocation`: (Optional) Semantic location identifier
- `additionalData`: (Optional) Additional custom data

**Example:**
```swift
ContentAnalytics.trackAssetClick(
    assetURL: "https://example.com/button.jpg",
    assetLocation: "home.cta"
)
```

---

### Experience Tracking

> ⚠️ **IMPORTANT**: You must call `registerExperience()` **before** tracking views or clicks. See the [Experience Tracking Guide](EXPERIENCE_TRACKING_GUIDE.md) for detailed usage patterns.

#### registerExperience

Registers an experience and returns an ID for tracking.

```swift
static func registerExperience(
    assets: [ContentItem],
    texts: [ContentItem],
    ctas: [ContentItem]? = nil
) -> String
```

**Parameters:**
- `assets`: Asset content items (URLs)
- `texts`: Text content items
- `ctas`: (Optional) Button/CTA content items

**Returns:** Experience ID (content-based hash)

> **Note:** Call before `trackExperienceView`/`trackExperienceClick`. Registration is idempotent.

**Example:**
```swift
let expId = ContentAnalytics.registerExperience(
    assets: [ContentItem(value: "https://example.com/product.jpg", styles: [:])],
    texts: [
        ContentItem(value: "iPhone 16 Pro", styles: ["role": "headline"]),
        ContentItem(value: "$999", styles: ["role": "price"])
    ],
    ctas: [ContentItem(value: "Buy Now", styles: ["enabled": true])]
)

ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "product.detail")
```

---

#### trackExperienceView

Tracks when an experience is viewed.

```swift
static func trackExperienceView(
    experienceId: String,
    experienceLocation: String? = nil,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `experienceId`: ID from `registerExperience()`
- `experienceLocation`: (Optional) Where the experience was viewed
- `additionalData`: (Optional) Custom data

**Example:**
```swift
ContentAnalytics.trackExperienceView(
    experienceId: expId,
    experienceLocation: "homepage.hero",
    additionalData: ["viewDuration": 5.2]
)
```

---

#### trackExperienceClick

Tracks when an experience is clicked.

```swift
static func trackExperienceClick(
    experienceId: String,
    experienceLocation: String? = nil,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `experienceId`: ID from `registerExperience()`
- `experienceLocation`: (Optional) Where the click occurred
- `additionalData`: (Optional) Custom data

**Example:**
```swift
ContentAnalytics.trackExperienceClick(
    experienceId: expId,
    experienceLocation: "homepage.hero",
    additionalData: ["element": "buyNow"]
)
```

---

## Objective-C API

All Swift APIs have Objective-C equivalents.

### Asset Tracking

```objective-c
// Track view (convenience method)
[ContentAnalytics trackAssetViewWithAssetURL:@"https://example.com/hero.jpg"
                               assetLocation:@"home.hero"
                              additionalData:nil];

// Track click (convenience method)
[ContentAnalytics trackAssetClickWithAssetURL:@"https://example.com/button.jpg"
                                assetLocation:@"home.cta"
                               additionalData:nil];

// Using InteractionType enum directly (AEPInteractionType)
[ContentAnalytics trackAsset:@"https://example.com/image.jpg"
              interactionType:AEPInteractionTypeView
                assetLocation:@"home"
               additionalData:nil];

// Or with click
[ContentAnalytics trackAsset:@"https://example.com/banner.jpg"
              interactionType:AEPInteractionTypeClick
                assetLocation:@"home.banner"
               additionalData:nil];
```

The `InteractionType` enum is Objective-C compatible:
- `AEPInteractionTypeView` (0)
- `AEPInteractionTypeClick` (1)

### Experience Tracking

```objective-c
// Register experience
NSString *expId = [ContentAnalytics 
    registerExperienceWithAssetURLs:@[@"https://example.com/product.jpg"]
                              texts:@[@"Product Name", @"$99.99"]
                               ctas:@[@"Add to Cart"]
                experienceLocation:@"product.detail"];

// Track view
[ContentAnalytics trackExperienceViewWithExperienceId:expId
                                       additionalData:nil];

// Track click
[ContentAnalytics trackExperienceClickWithExperienceId:expId
                                        additionalData:nil];
```

---

## Data Types

### InteractionType

Interaction type enum (Objective-C compatible).

```swift
@objc(AEPInteractionType)
public enum InteractionType: Int {
    case view = 0
    case click = 1
    
    public var stringValue: String { ... }
    public static func from(string: String) -> InteractionType?
}
```

**Swift Usage:**
```swift
ContentAnalytics.trackAsset(
    assetURL: "https://example.com/hero.jpg",
    interactionType: .view
)
```

**Objective-C Usage:**
```objective-c
[ContentAnalytics trackAsset:@"https://example.com/hero.jpg"
              interactionType:AEPInteractionTypeView
                assetLocation:nil
               additionalData:nil];
```

### ContentItem

Represents content within an experience (assets, texts, CTAs).

```swift
public struct ContentItem {
    let value: String
    let styles: [String: Any]
    
    init(value: String, styles: [String: Any])
}
```

**Usage:**
```swift
// Asset
ContentItem(value: "https://example.com/image.jpg", styles: [:])

// Text with role
ContentItem(value: "Product Title", styles: ["role": "headline"])
ContentItem(value: "$99.99", styles: ["role": "price"])

// CTA
ContentItem(value: "Buy Now", styles: ["enabled": true])
```

---

## Configuration

Managed through Adobe Data Collection:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `configId` | String | - | Custom datastream for Content Analytics events (overrides `edge.configId`) |
| `batchingEnabled` | Boolean | `true` | Enable batching |
| `maxBatchSize` | Integer | `10` | Max events per batch |
| `flushInterval` | Double | `2.0` | Flush interval (seconds) |
| `trackExperiences` | Boolean | `true` | Enable experiences |
| `excludedAssetLocationsRegexp` | String | - | Asset location regex pattern (e.g., `"^(debug\|test).*"`) |
| `excludedAssetUrlsRegexp` | String | - | Asset URL regex pattern (e.g., `".*\\.gif$\|.*\\.svg$"`) |
| `excludedExperienceLocationsRegexp` | String | - | Experience location regex pattern (e.g., `"^test\\..*\|^dev\\..*"`) |
| `debugLogging` | Boolean | `false` | Verbose logging |

---

## Privacy

```swift
MobileCore.setPrivacyStatus(.optedIn)  // enable tracking
MobileCore.setPrivacyStatus(.optedOut)  // disable tracking
```

When opted out, no events are sent.

---

## Additional Resources

- [Getting Started](getting-started.md)
- [Advanced Configuration](advanced-configuration.md)
- [Troubleshooting](troubleshooting.md)

