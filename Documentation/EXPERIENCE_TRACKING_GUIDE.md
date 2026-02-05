# Experience Tracking Usage Guide

Experience tracking measures how users interact with complete experiences (combinations of images, text, and CTAs) in your app.

## Quick Start

```swift
// 1. Register (once per experience)
let expId = ContentAnalytics.registerExperience(
    assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
    texts: [ContentItem(value: "Buy Now", styles: ["role": "headline"])],
    ctas: [ContentItem(value: "Shop", styles: ["enabled": true])]
)

// 2. Track view (when visible)
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "homepage.hero")

// 3. Track click (on tap)
ContentAnalytics.trackExperienceClick(experienceId: expId, experienceLocation: "homepage.hero")
```

That's it. Register first, then track views/clicks using the returned ID.

---

## Registration Required

You must register an experience definition before tracking views or clicks. If you don't:
- Asset attribution won't work
- Featurization hits won't be sent
- A warning will be logged

## Basic Usage

Register the experience once with all its content:

```swift
let experienceId = ContentAnalytics.registerExperience(
    assets: [
        ContentItem(value: "https://example.com/hero.jpg", styles: [:]),
        ContentItem(value: "https://example.com/icon.png", styles: [:])
    ],
    texts: [
        ContentItem(value: "iPhone 16 Pro", styles: ["role": "headline"]),
        ContentItem(value: "Forged in titanium", styles: ["role": "body"]),
        ContentItem(value: "$999", styles: ["role": "price"])
    ],
    ctas: [
        ContentItem(value: "Buy Now", styles: ["enabled": true])
    ]
)
```

Then track interactions:

```swift
ContentAnalytics.trackExperienceView(experienceId: experienceId, experienceLocation: "product.detail")
ContentAnalytics.trackExperienceClick(experienceId: experienceId, experienceLocation: "product.detail")
```

## Session Lifecycle

Experience definitions are cached in memory for the duration of the app session. After app restart or crash, you'll need to re-register experiences before tracking.

```swift
// Each app session
let expId = ContentAnalytics.registerExperience(
    assets: [ContentItem(value: "https://example.com/hero.jpg", styles: [:])],
    texts: [ContentItem(value: "Title", styles: ["role": "headline"])]
)
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "home")
```

Re-registration is idempotent - calling `registerExperience()` with the same content returns the same ID with no negative side effects. The featurization service is also idempotent, so even if the same experience definition is sent multiple times (e.g., after cache eviction or app restart), there's no duplication or data inconsistency on the backend.

### Cache Behavior

The SDK uses an LRU (Least Recently Used) cache with a capacity of **100 experience definitions**:

- **Capacity:** 100 definitions max
- **Eviction:** When full, least recently used definitions are removed
- **Memory-only:** Not persisted to disk

**Benefits:**
- Fast lookups for asset attribution
- Bounded memory usage (~20-40KB worst case)
- Automatic cleanup of stale definitions
- No disk I/O overhead
- **Safe re-registration:** Featurization service handles duplicates gracefully

For most apps, 100 definitions is sufficient. If you're registering more unique experiences per session, consider reusing experience IDs where content is identical (same content = same ID).

## Implementation Patterns

### Single Screen

```swift
class ProductDetailViewController {
    var experienceId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        experienceId = ContentAnalytics.registerExperience(
            assets: product.imageURLs.map { ContentItem(value: $0, styles: [:]) },
            texts: [
                ContentItem(value: product.name, styles: ["role": "headline"]),
                ContentItem(value: product.price, styles: ["role": "price"])
            ],
            ctas: [ContentItem(value: "Add to Cart", styles: ["enabled": true])]
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let expId = experienceId {
            ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "product.detail.\(product.id)")
        }
    }
    
    @IBAction func buyButtonTapped(_ sender: Any) {
        if let expId = experienceId {
            ContentAnalytics.trackExperienceClick(experienceId: expId, experienceLocation: "product.detail.\(product.id)")
        }
    }
}
```

### Collection/Feed

```swift
class FeedViewController: UIViewController {
    var experienceIds: [String: String] = [:]
    
    func displayProduct(_ product: Product) {
        if experienceIds[product.id] == nil {
            let expId = ContentAnalytics.registerExperience(
                assets: product.imageURLs.map { ContentItem(value: $0, styles: [:]) },
                texts: [ContentItem(value: product.name, styles: ["role": "headline"])]
            )
            experienceIds[product.id] = expId
        }
    }
    
    func productCellBecameVisible(_ product: Product) {
        if let expId = experienceIds[product.id] {
            ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "feed.item.\(product.id)")
        }
    }
}
```

### Experience ID Generation

Experience IDs are deterministic - the same content always produces the same ID. The algorithm:

1. Sort text values alphabetically
2. Sort asset URLs alphabetically  
3. Sort CTA values alphabetically
4. Join all with `|` separator (texts, then assets, then CTAs)
5. SHA-1 hash the combined string
6. Take first 12 hex characters
7. Prefix with `mobile-`

**Example:**
```swift
// Content: texts=["$99", "Product"], assets=["img.jpg"], ctas=["Buy"]
// Sorted & joined: "Product|$99|img.jpg|Buy"
// SHA-1 → first 12 chars → "mobile-a1b2c3d4e5f6"
```

This means you can:
- **Pre-compute IDs server-side** for consistent cross-platform IDs
- **Cache by content hash** instead of arbitrary keys
- **Detect content changes** by comparing IDs

```swift
import CommonCrypto

func computeExperienceId(texts: [String], assets: [String], ctas: [String]) -> String {
    let content = (texts.sorted() + assets.sorted() + ctas.sorted()).joined(separator: "|")
    let hash = content.data(using: .utf8)!.sha1Hex()
    return "mobile-\(hash.prefix(12))"
}
```

## Missing Registration Warning

If you track without registering:

```
⚠️ Experience definition not found for 'exp-123'. 
   Call registerExperience() before tracking views/clicks.
```

This means:
- View/click events still go to Analytics
- But asset attribution won't work
- Featurization service won't get the data

Fix by registering first:

```swift
// Wrong
ContentAnalytics.trackExperienceView(experienceId: "exp-123")

// Correct
let expId = ContentAnalytics.registerExperience(...)
ContentAnalytics.trackExperienceView(experienceId: expId)
```

## Asset Attribution

When you register an experience with assets, the SDK links those asset URLs to the experience. This enables **asset attribution** - connecting standalone asset tracking events to their parent experience.

> **Note:** Asset attribution works regardless of the `batchingEnabled` setting. The SDK caches experience definitions locally, so attribution is based on the registration cache - not on how events are batched for network delivery.

### How It Works

```swift
// 1. Register experience with assets
let expId = ContentAnalytics.registerExperience(
    assets: [
        ContentItem(value: "https://example.com/hero.jpg", styles: [:]),
        ContentItem(value: "https://example.com/thumbnail.jpg", styles: [:])
    ],
    texts: [ContentItem(value: "Summer Sale", styles: ["role": "headline"])]
)

// 2. Track asset view (SDK knows this belongs to the experience above)
ContentAnalytics.trackAssetView(assetURL: "https://example.com/hero.jpg")

// 3. Track experience interaction
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "homepage")
```

When the analytics backend receives `trackAssetView` for `hero.jpg`, it can attribute that view to the "Summer Sale" experience because the asset URL was registered.

### Without Attribution

If you track an asset without registering the experience first:

```swift
// Asset tracked standalone - no experience context
ContentAnalytics.trackAssetView(assetURL: "https://example.com/hero.jpg")
```

The asset view is still recorded, but it's not linked to any experience. You lose:
- Which experience contained this asset
- Performance metrics per experience
- A/B test attribution

### When to Use Each

| Scenario | Approach |
|----------|----------|
| Image in a banner/card with text/CTA | Register experience with assets, track both |
| Standalone image (no surrounding content) | Just `trackAssetView` |
| Image gallery | `trackAssetCollection` or individual `trackAssetView` |
| Product card with image + title + price | Register experience, attribution links them |

## Location Strategy

The `experienceLocation` and `assetLocation` parameters control how metrics are grouped in Customer Journey Analytics (CJA).

### With Location - Metrics Per Placement

```swift
// Same experience tracked at different locations
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "homepage.hero")
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "product.sidebar")
ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "checkout.upsell")
```

**CJA Report:**

| Experience | Location | Views | Clicks | CTR |
|------------|----------|-------|--------|-----|
| Summer Sale | homepage.hero | 10,000 | 500 | 5% |
| Summer Sale | product.sidebar | 3,000 | 90 | 3% |
| Summer Sale | checkout.upsell | 1,000 | 150 | 15% |

This lets you answer: *"Where does this experience perform best?"*

### Without Location - Global Metrics

```swift
// Track without location for aggregate metrics
ContentAnalytics.trackExperienceView(experienceId: expId)
```

**CJA Report:**

| Experience | Views | Clicks | CTR |
|------------|-------|--------|-----|
| Summer Sale | 14,000 | 740 | 5.3% |

This lets you answer: *"How is this experience performing overall?"*

### Same Asset, Different Locations

```swift
let heroImage = "https://example.com/hero.jpg"

// Track per location
ContentAnalytics.trackAssetView(assetURL: heroImage, assetLocation: "homepage")
ContentAnalytics.trackAssetView(assetURL: heroImage, assetLocation: "category.electronics")
ContentAnalytics.trackAssetView(assetURL: heroImage, assetLocation: "search.results")
```

**CJA Report:**

| Asset | Location | Views | Clicks |
|-------|----------|-------|--------|
| hero.jpg | homepage | 50,000 | 2,500 |
| hero.jpg | category.electronics | 8,000 | 320 |
| hero.jpg | search.results | 3,000 | 45 |

### Location Naming Conventions

Use a consistent hierarchy for easier filtering in CJA:

```
screen.section.subsection
```

Examples:
- `homepage.hero`
- `homepage.featured`
- `product.detail.recommendations`
- `cart.upsell`
- `search.results.sponsored`

### When to Use Location

| Goal | Location |
|------|----------|
| Compare same content across placements | ✅ Set location |
| A/B test content in a specific spot | ✅ Set location |
| Track overall content performance | ❌ Omit location |
| Simple asset tracking (no placement analysis) | ❌ Omit location |

## ML-Powered Analytics

When you register experiences, the featurization service analyzes the content and extracts ML attributes like **persuasion strategy**, **emotional tone**, **content category**, etc. These attributes are then available in CJA for advanced analysis.

### Performance by Persuasion Strategy

After featurization, CJA can show which persuasion strategies work best in each location:

**CJA Report - Persuasion Strategy by Location:**

| Location | Persuasion Strategy | Views | Clicks | CTR |
|----------|---------------------|-------|--------|-----|
| homepage.hero | Urgency | 10,000 | 800 | 8% |
| homepage.hero | Social Proof | 10,000 | 650 | 6.5% |
| homepage.hero | Scarcity | 10,000 | 720 | 7.2% |
| checkout.upsell | Urgency | 2,000 | 300 | 15% |
| checkout.upsell | Social Proof | 2,000 | 180 | 9% |

*Insight: "Urgency" messaging performs best at checkout (+15% CTR), while "Social Proof" works better on homepage.*

### Performance by Content Category

**CJA Report - Asset Category Performance:**

| Asset Category | Location | Views | Engagement |
|----------------|----------|-------|------------|
| Lifestyle | homepage | 50,000 | 12% |
| Product-focused | homepage | 50,000 | 8% |
| Lifestyle | product.detail | 20,000 | 6% |
| Product-focused | product.detail | 20,000 | 14% |

*Insight: Lifestyle imagery works on homepage, but product-focused images convert better on detail pages.*

### How It Works

1. **You track** - `registerExperience()` sends content to featurization service
2. **ML analyzes** - Service extracts persuasion strategy, tone, category, etc.
3. **Attributes stored** - ML attributes are linked to the experience/asset
4. **CJA queries** - Reports can segment by any ML attribute + location

```swift
// You just track normally - ML attributes are automatic
let expId = ContentAnalytics.registerExperience(
    assets: [ContentItem(value: "https://example.com/urgency-banner.jpg", styles: [:])],
    texts: [
        ContentItem(value: "Only 3 left!", styles: ["role": "headline"]),
        ContentItem(value: "Order now before it's gone", styles: ["role": "body"])
    ]
)
// Featurization service detects: persuasion_strategy = "scarcity + urgency"

ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "product.detail")
```

In CJA, you can then filter/group by `persuasion_strategy` to see what messaging resonates in each location.

## Custom Metrics with additionalData

The `additionalData` parameter lets you attach custom metrics to tracking events. These appear in CJA as additional dimensions/metrics.

### Asset Performance Metrics

```swift
// Track asset load time
let loadStart = Date()
// ... load image ...
let loadTime = Date().timeIntervalSince(loadStart) * 1000 // ms

ContentAnalytics.trackAssetView(
    assetURL: imageURL,
    assetLocation: "product.gallery",
    additionalData: [
        "assetLoadTime": loadTime,           // How long to load (ms)
        "assetSize": imageData.count,        // Bytes
        "assetSource": "cdn"                 // Cache vs CDN
    ]
)
```

### Asset View Duration

```swift
class ImageViewController {
    var viewStartTime: Date?
    var imageURL: String?
    
    func viewDidAppear() {
        viewStartTime = Date()
        ContentAnalytics.trackAssetView(assetURL: imageURL!, assetLocation: "gallery")
    }
    
    func viewWillDisappear() {
        guard let start = viewStartTime else { return }
        let viewDuration = Date().timeIntervalSince(start) * 1000 // ms
        
        ContentAnalytics.trackAssetClick(
            assetURL: imageURL!,
            assetLocation: "gallery",
            additionalData: [
                "assetViewDuration": viewDuration  // Time spent viewing (ms)
            ]
        )
    }
}
```

### Experience Engagement Metrics

```swift
class ProductCardView {
    var expId: String?
    var appearTime: Date?
    
    func onAppear() {
        appearTime = Date()
        expId = ContentAnalytics.registerExperience(
            assets: [ContentItem(value: product.imageURL, styles: [:])],
            texts: [ContentItem(value: product.name, styles: ["role": "headline"])]
        )
        ContentAnalytics.trackExperienceView(
            experienceId: expId!,
            experienceLocation: "homepage.featured"
        )
    }
    
    func onTap() {
        let viewDuration = Date().timeIntervalSince(appearTime!) * 1000
        
        ContentAnalytics.trackExperienceClick(
            experienceId: expId!,
            experienceLocation: "homepage.featured",
            additionalData: [
                "experienceViewDuration": viewDuration,  // Time before click (ms)
                "scrollDepth": currentScrollPercent,     // How far user scrolled
                "interactionIndex": tapCount             // Nth interaction
            ]
        )
    }
}
```

### Common Custom Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `assetLoadTime` | Double | Image/video load time (ms) |
| `assetViewDuration` | Double | Time asset was visible (ms) |
| `assetSize` | Int | Asset file size (bytes) |
| `experienceViewDuration` | Double | Time before interaction (ms) |
| `scrollDepth` | Double | Scroll position when viewed (%) |
| `viewportPosition` | String | "above_fold" / "below_fold" |
| `interactionIndex` | Int | Nth click on this session |
| `experimentVariant` | String | A/B test variant ID |
| `deviceOrientation` | String | "portrait" / "landscape" |

### CJA Report with Custom Metrics

**Average Load Time by Asset Location:**

| Location | Avg Load Time | Avg View Duration |
|----------|---------------|-------------------|
| homepage.hero | 120ms | 3.2s |
| product.gallery | 85ms | 8.5s |
| search.results | 45ms | 1.1s |

*Insight: Gallery images load slower but get 8x more viewing time.*

## Best Practice

Always call `registerExperience()` before `trackExperienceView()`/`trackExperienceClick()`. Registration is idempotent - calling it multiple times has no negative effects.

## Debugging with Assurance

Adobe Assurance (Project Griffon) lets you inspect tracking events in real-time. Connect your app to an Assurance session to see exactly what payloads are being sent.

### Setup

```swift
// In your app delegate or SwiftUI app
import AEPAssurance

// Start Assurance session (typically via deep link)
Assurance.startSession(url: assuranceDeepLink)
```

### What You'll See in Assurance

**1. Track Asset Events**

When you call `trackAssetView()` or `trackAssetClick()`, you'll see:

```
Event: Track Asset
Type: com.adobe.eventType.contentAnalytics
Source: com.adobe.eventSource.requestContent

Payload:
{
  "assetURL": "https://example.com/hero.jpg",
  "interactionType": "view",
  "assetLocation": "homepage.hero",
  "assetExtras": {
    "assetLoadTime": 120,
    "assetSize": 45000
  }
}
```

**2. Track Experience Events**

When you call `registerExperience()`:

```
Event: Track Experience
Type: com.adobe.eventType.contentAnalytics

Payload:
{
  "experienceId": "mobile-abc123...",
  "interactionType": "definition",
  "assetURLs": ["https://example.com/hero.jpg"],
  "texts": [
    {"value": "Summer Sale", "styles": {"role": "headline"}}
  ],
  "ctas": [
    {"value": "Shop Now", "styles": {"enabled": true}}
  ]
}
```

When you call `trackExperienceView()` or `trackExperienceClick()`:

```
Event: Track Experience
Type: com.adobe.eventType.contentAnalytics

Payload:
{
  "experienceId": "mobile-abc123...",
  "interactionType": "view",
  "experienceLocation": "homepage.hero",
  "experienceExtras": {
    "experienceViewDuration": 3500
  }
}
```

**3. Edge Network Events**

After batching, you'll see the Edge request:

```
Event: Edge Request
Type: com.adobe.eventType.edge

Payload:
{
  "xdm": {
    "eventType": "contentanalytics.asset.view",
    "_contentanalytics": {
      "asset": {
        "url": "https://example.com/hero.jpg",
        "location": "homepage.hero"
      }
    }
  }
}
```

### Debugging Checklist

| What to Check | Where in Assurance |
|---------------|-------------------|
| Event dispatched | Look for `Track Asset` / `Track Experience` events |
| Correct payload | Expand event → check `assetURL`, `experienceId`, etc. |
| Batching working | Multiple events → single Edge request |
| Edge delivery | Look for `Edge Request` after batch flush |
| Consent status | Check `Edge Consent` events |

### Common Issues in Assurance

**No events appearing:**
- Check extension is registered
- Verify `MobileCore.dispatch()` is being called

**Events but no Edge request:**
- Check consent status (must be "yes" or "pending")
- Wait for batch timeout (default 5s) or threshold (default 10 events)

**Missing experienceId in track events:**
- Ensure `registerExperience()` was called first
- Check the returned ID is being passed to track methods

## Testing

Enable verbose logging:

```swift
MobileCore.setLogLevel(.trace)
```

Look for registration confirmation:
```
[ContentAnalytics] Stored experience definition: exp-abc123 with 3 assets
```

And tracking confirmation:
```
[ContentAnalytics] Experience event processed successfully: track-view - exp-abc123
```

Test cross-session: register, force quit, relaunch, track same ID. No warning should appear.

## Troubleshooting

**"Experience definition not found" warning**

Register the experience before tracking it.

**Assets not attributed**

Same issue - register with `assetURLs` before tracking.

**Duplicate registrations**

Check if already registered before calling `registerExperience()`:

```swift
if experienceIds[productId] == nil {
    experienceIds[productId] = ContentAnalytics.registerExperience(...)
}
```

Or compute the ID yourself using the algorithm above for content-based caching.

## Common Patterns

### Carousel/Banner

```swift
class CarouselView: UIView {
    private var experienceIds: [Int: String] = [:]
    
    func configureSlide(_ slide: Slide, at index: Int) {
        experienceIds[index] = ContentAnalytics.registerExperience(
            assets: [ContentItem(value: slide.imageURL, styles: [:])],
            texts: [ContentItem(value: slide.title, styles: ["role": "headline"])],
            ctas: slide.ctaText.map { [ContentItem(value: $0, styles: ["enabled": true])] }
        )
    }
    
    func slideDidAppear(at index: Int) {
        guard let expId = experienceIds[index] else { return }
        ContentAnalytics.trackExperienceView(experienceId: expId, experienceLocation: "home.carousel.\(index)")
    }
    
    func slideWasTapped(at index: Int) {
        guard let expId = experienceIds[index] else { return }
        ContentAnalytics.trackExperienceClick(experienceId: expId, experienceLocation: "home.carousel.\(index)")
    }
}
```

### Product Grid (SwiftUI)

```swift
struct ProductCard: View {
    let product: Product
    @State private var expId: String?
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: product.imageURL))
            Text(product.name)
            Text(product.price)
        }
        .onAppear {
            if expId == nil {
                expId = ContentAnalytics.registerExperience(
                    assets: [ContentItem(value: product.imageURL, styles: [:])],
                    texts: [
                        ContentItem(value: product.name, styles: ["role": "headline"]),
                        ContentItem(value: product.price, styles: ["role": "price"])
                    ]
                )
            }
            if let id = expId {
                ContentAnalytics.trackExperienceView(experienceId: id, experienceLocation: "catalog.product.\(product.id)")
            }
        }
        .onTapGesture {
            if let id = expId {
                ContentAnalytics.trackExperienceClick(experienceId: id, experienceLocation: "catalog.product.\(product.id)")
            }
        }
    }
}
```

### Reusable Tracking Component

```swift
struct TrackedExperience<Content: View>: View {
    let assets: [ContentItem]
    let texts: [ContentItem]
    let location: String
    let content: Content
    
    @State private var expId: String?
    
    init(
        assets: [ContentItem],
        texts: [ContentItem],
        location: String,
        @ViewBuilder content: () -> Content
    ) {
        self.assets = assets
        self.texts = texts
        self.location = location
        self.content = content()
    }
    
    var body: some View {
        content
            .onAppear {
                if expId == nil {
                    expId = ContentAnalytics.registerExperience(assets: assets, texts: texts)
                }
                if let id = expId {
                    ContentAnalytics.trackExperienceView(experienceId: id, experienceLocation: location)
                }
            }
            .onTapGesture {
                if let id = expId {
                    ContentAnalytics.trackExperienceClick(experienceId: id, experienceLocation: location)
                }
            }
    }
}

// Usage
TrackedExperience(
    assets: [ContentItem(value: product.imageURL, styles: [:])],
    texts: [ContentItem(value: product.name, styles: ["role": "headline"])],
    location: "product.\(product.id)"
) {
    ProductCardView(product: product)
}
```

## See Also

- [API Reference](api-reference.md) - Complete API documentation
- [Crash Recovery](crash-recovery.md) - Persistence implementation details
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
