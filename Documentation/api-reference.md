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

Registers an experience and returns an ID for future tracking.

```swift
static func registerExperience(
    assetURLs: [String],
    texts: [ExperienceTextContent],
    ctas: [ExperienceButtonContent]? = nil,
    experienceLocation: String
) -> String
```

**Parameters:**
- `assetURLs`: Array of asset URLs in the experience
- `texts`: Array of text content (`ExperienceTextContent` objects)
- `ctas`: (Optional) Array of button/CTA content
- `experienceLocation`: Location identifier for the experience (used for categorization)

**Returns:** Experience ID string (e.g., "mobile-abc123...")

> **⚠️ Warning:** You must call this method **before** tracking views or clicks for the experience. Failure to do so will result in incomplete data (assets won't be attributed, featurization won't occur).

> **📌 Note:** Experience definitions are cached in memory for the app session. Re-register on app launch for experiences you need to track. Registration is idempotent.

**Example:**
```swift
// Step 1: Register experience (do this FIRST)
let expId = ContentAnalytics.registerExperience(
    assetURLs: ["https://example.com/product.jpg"],
    texts: [
        ExperienceTextContent(text: "iPhone 16 Pro", textRole: .headline),
        ExperienceTextContent(text: "$999", textRole: .body)
    ],
    ctas: [
        ExperienceButtonContent(text: "Buy Now", isEnabled: true)
    ],
    experienceLocation: "product.detail.iphone16pro"
)

// Step 2: Track interactions (use the returned ID)
ContentAnalytics.trackExperienceView(experienceId: expId)
```

---

#### trackExperienceView

Tracks when an experience is viewed.

```swift
static func trackExperienceView(
    experienceId: String,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `experienceId`: The ID returned from `registerExperience()`
- `additionalData`: (Optional) Additional custom data

> **⚠️ Prerequisite:** You must call `registerExperience()` for this experience ID before calling this method. If the experience definition is not found, a warning will be logged and asset attribution will not occur.

**Example:**
```swift
// First, register the experience
let expId = ContentAnalytics.registerExperience(...)

// Then track view
ContentAnalytics.trackExperienceView(
    experienceId: expId,
    additionalData: ["viewDuration": 5.2]
)
```

---

#### trackExperienceClick

Tracks when an experience is clicked.

```swift
static func trackExperienceClick(
    experienceId: String,
    additionalData: [String: Any]? = nil
)
```

**Parameters:**
- `experienceId`: The ID returned from `registerExperience()`
- `additionalData`: (Optional) Additional custom data

> **⚠️ Prerequisite:** You must call `registerExperience()` for this experience ID before calling this method. If the experience definition is not found, a warning will be logged and asset attribution will not occur.

**Example:**
```swift
// First, register the experience
let expId = ContentAnalytics.registerExperience(...)

// Then track click
ContentAnalytics.trackExperienceClick(
    experienceId: expId,
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

### ExperienceTextContent

Represents text content within an experience.

```swift
struct ExperienceTextContent {
    let text: String
    let textRole: TextRole?
    
    enum TextRole: String {
        case headline
        case body
    }
}
```

### ExperienceButtonContent

Represents button/CTA content within an experience.

```swift
struct ExperienceButtonContent {
    let text: String
    let isEnabled: Bool
}
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
| `featurizationServiceUrl` | String | - | ML service URL |
| `excludedAssetLocations` | Array | `[]` | Asset locations to exclude (exact match) |
| `excludedAssetUrlsRegexp` | String | - | Asset URL regex pattern (e.g., `".*\\.gif$\|.*\\.svg$"`) |
| `excludedExperienceLocations` | Array | `[]` | Experience locations to exclude (exact match) |
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

