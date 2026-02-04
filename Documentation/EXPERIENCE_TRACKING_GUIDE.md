# Experience Tracking Usage Guide

Experience tracking measures how users interact with complete experiences (combinations of images, text, and CTAs) in your app.

## Registration Required

You must register an experience definition before tracking views or clicks. If you don't:
- Asset attribution won't work
- Featurization hits won't be sent
- A warning will be logged

## Basic Usage

Register the experience once with all its content:

```swift
let experienceId = ContentAnalytics.registerExperience(
    assetURLs: [
        "https://example.com/hero.jpg",
        "https://example.com/icon.png"
    ],
    texts: [
        ExperienceTextContent(text: "iPhone 16 Pro", textRole: .headline),
        ExperienceTextContent(text: "Forged in titanium", textRole: .body),
        ExperienceTextContent(text: "$999", textRole: .body)
    ],
    ctas: [
        ExperienceButtonContent(text: "Buy Now", isEnabled: true)
    ],
    experienceLocation: "product.detail.iphone16pro"
)
```

Then track interactions:

```swift
ContentAnalytics.trackExperienceView(experienceId: experienceId)
ContentAnalytics.trackExperienceClick(experienceId: experienceId)
```

## Session Lifecycle

Experience definitions are cached in memory for the duration of the app session. After app restart or crash, you'll need to re-register experiences before tracking.

```swift
// Each app session
let expId = ContentAnalytics.registerExperience(
    assetURLs: ["https://example.com/hero.jpg"],
    texts: [...],
    ...
)
ContentAnalytics.trackExperienceView(experienceId: expId)
```

Re-registration is idempotent - calling `registerExperience()` with the same content has no negative side effects.

## Implementation Patterns

### Single Screen

```swift
class ProductDetailViewController {
    var experienceId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        experienceId = ContentAnalytics.registerExperience(
            assetURLs: product.imageURLs,
            texts: [
                ExperienceTextContent(text: product.name, textRole: .headline),
                ExperienceTextContent(text: product.price, textRole: .body)
            ],
            ctas: [ExperienceButtonContent(text: "Add to Cart", isEnabled: true)],
            experienceLocation: "product.detail.\(product.id)"
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let expId = experienceId {
            ContentAnalytics.trackExperienceView(experienceId: expId)
        }
    }
    
    @IBAction func buyButtonTapped(_ sender: Any) {
        if let expId = experienceId {
            ContentAnalytics.trackExperienceClick(experienceId: expId)
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
                assetURLs: product.imageURLs,
                texts: [ExperienceTextContent(text: product.name, textRole: .headline)],
                ctas: nil,
                experienceLocation: "feed.item.\(product.id)"
            )
            experienceIds[product.id] = expId
        }
    }
    
    func productCellBecameVisible(_ product: Product) {
        if let expId = experienceIds[product.id] {
            ContentAnalytics.trackExperienceView(experienceId: expId)
        }
    }
}
```

### Persistent IDs

If you have stable server-provided IDs, store and reuse them:

```swift
let experienceIdKey = "exp_\(product.id)"

if let cachedExpId = UserDefaults.standard.string(forKey: experienceIdKey) {
    experienceId = cachedExpId
} else {
    let expId = ContentAnalytics.registerExperience(...)
    UserDefaults.standard.set(expId, forKey: experienceIdKey)
    experienceId = expId
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

## Best Practice

Always call `registerExperience()` before `trackExperienceView()`/`trackExperienceClick()`. Registration is idempotent - calling it multiple times has no negative effects.

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

Or use stable IDs stored in UserDefaults.

## See Also

- [API Reference](api-reference.md) - Complete API documentation
- [Crash Recovery](crash-recovery.md) - Persistence implementation details
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
