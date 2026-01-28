# Getting Started with AEP Content Analytics Extension

This guide will help you integrate the AEP Content Analytics extension into your iOS application.

## Prerequisites

- iOS 12.0+ or tvOS 12.0+
- Xcode 14.0+
- Swift 5.5+
- Adobe Experience Platform Mobile SDK Core and Edge extensions

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, select **File > Add Package Dependencies**
2. Enter the package URL:
   ```
   https://github.com/adobe/aca-mobile-sdk-ios-extension
   ```
3. Select version `5.0.0` or later
4. Click **Add Package**

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'AEPContentAnalytics', '~> 5.0'
```

Run:
```bash
pod install
```

## Configuration

### 1. Configure Adobe Experience Platform

In the [Data Collection UI](https://experience.adobe.com/data-collection):

1. Create or select a mobile property
2. Install the **Content Analytics** extension
3. Configure settings (batching enabled by default, 10 events per batch, 2 second flush interval)
4. Publish

### 2. Initialize the SDK

In `AppDelegate.swift`:

```swift
import AEPCore
import AEPEdge
import AEPContentAnalytics

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    MobileCore.setLogLevel(.debug) // optional
    MobileCore.configureWith(appId: "YOUR_ENVIRONMENT_FILE_ID")
    
    MobileCore.registerExtensions([
        Edge.self,
        ContentAnalytics.self
    ]) {
        print("AEP SDK initialized")
    }
    
    return true
}
```

### 3. Set Privacy Status

```swift
// User opts in
MobileCore.setPrivacyStatus(.optedIn)

// User opts out
MobileCore.setPrivacyStatus(.optedOut)
```

## Basic Usage

### Track an Asset (Image, Media)

```swift
// Track when an asset is viewed
ContentAnalytics.trackAssetView(
    assetURL: "https://example.com/hero-image.jpg",
    assetLocation: "home.hero"
)

// Track when an asset is clicked
ContentAnalytics.trackAssetClick(
    assetURL: "https://example.com/cta-button.jpg",
    assetLocation: "home.cta"
)
```

### Track an Experience (Complex UI)

```swift
// 1. Register the experience
let experienceId = ContentAnalytics.registerExperience(
    assetURLs: ["https://example.com/product.jpg"],
    texts: ["Product Name", "Price: $99.99", "In Stock"],
    ctas: ["Add to Cart", "Save for Later"],
    experienceLocation: "product.detail"
)

// 2. Track interactions
ContentAnalytics.trackExperienceView(experienceId: experienceId)

ContentAnalytics.trackExperienceClick(
    experienceId: experienceId,
    additionalData: ["element": "addToCart"]
)
```

## Next Steps

- [API Reference](api-reference.md) - Complete API documentation
- [Advanced Configuration](advanced-configuration.md) - Detailed configuration options
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Support

- [GitHub Issues](https://github.com/adobe/aca-mobile-sdk-ios-extension/issues)
- [Adobe Experience League](https://experienceleague.adobe.com/)

