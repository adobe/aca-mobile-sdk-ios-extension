# Content Analytics Extension Documentation

Documentation for the AEP Content Analytics Extension.

## Getting Started

- [Getting Started Guide](getting-started.md) - Installation, configuration, and basic usage
- [API Reference](api-reference.md) - Complete API documentation
- [Sample App](../SampleApps/AEPContentAnalyticsDemo) - Working example

## Advanced Topics

- [Advanced Configuration](advanced-configuration.md) - Batching, privacy, performance tuning, ML featurization
- [Troubleshooting](troubleshooting.md) - Common issues and debugging

## What is Content Analytics?

The AEP Content Analytics Extension enables tracking of:

- **Assets**: Images, media, and content elements
- **Experiences**: Complex UI components (hero banners, product cards, etc.)

Features:
- Automatic batching and aggregation
- 100% data delivery guarantee
- Privacy-compliant tracking
- ML featurization support
- Edge Network integration
- Swift and Objective-C support

## Quick Start

### Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/adobe/aca-mobile-sdk-ios-extension", from: "5.0.0")
]
```

### Initialize

```swift
import AEPCore
import AEPEdge
import AEPContentAnalytics

MobileCore.registerExtensions([Edge.self, ContentAnalytics.self])
MobileCore.configureWith(appId: "YOUR_ENVIRONMENT_FILE_ID")
```

### Track

```swift
// Track asset
ContentAnalytics.trackAssetView(
    assetURL: "https://example.com/hero.jpg",
    assetLocation: "home.hero"
)

// Track experience
let expId = ContentAnalytics.registerExperience(
    assetURLs: ["https://example.com/product.jpg"],
    texts: [ExperienceTextContent(text: "Product Name")],
    ctas: [ExperienceButtonContent(text: "Buy Now", isEnabled: true)],
    experienceLocation: "product.detail"
)
ContentAnalytics.trackExperienceView(experienceId: expId)
```

## Help

- [File an issue](https://github.com/adobe/aca-mobile-sdk-ios-extension/issues)
- [GitHub Discussions](https://github.com/adobe/aca-mobile-sdk-ios-extension/discussions)

## Additional Resources

- [Main README](../README.md) - Project overview
- [CHANGELOG](../CHANGELOG.md) - Version history
- [CONTRIBUTING](../CONTRIBUTING.md) - How to contribute
- [LICENSE](../LICENSE) - Apache License 2.0
