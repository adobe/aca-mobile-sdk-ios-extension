# Adobe Experience Platform Content Analytics Mobile Extension

[![CocoaPods](https://img.shields.io/github/v/release/adobe/aca-mobile-sdk-ios-extension?label=CocoaPods&logo=apple&logoColor=white&color=orange)](https://cocoapods.org/pods/AEPContentAnalytics)
[![SPM](https://img.shields.io/github/v/release/adobe/aca-mobile-sdk-ios-extension?label=SPM&logo=apple&logoColor=white&color=orange)](https://github.com/adobe/aca-mobile-sdk-ios-extension/releases)
[![Build](https://github.com/adobe/aca-mobile-sdk-ios-extension/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/adobe/aca-mobile-sdk-ios-extension/actions)
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aca-mobile-sdk-ios-extension/main.svg?label=Coverage&logo=codecov)](https://codecov.io/gh/adobe/aca-mobile-sdk-ios-extension/branch/main)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## About this project

The AEP Content Analytics mobile extension tracks content and experience interactions in iOS apps. It batches events for efficiency, persists them to disk to survive crashes, and can optionally send data to an ML featurization service.

Requires `AEPCore`, `AEPServices`, and `AEPEdge` extensions to send data to the Adobe Experience Platform Edge Network.

See the [Adobe Experience Platform Content Analytics docs](https://developer.adobe.com/client-sdks/documentation/content-analytics/) for more.

## Requirements
- Xcode 15 (or newer)
- Swift 5.1 (or newer)

## Installation

These are currently the supported installation options:

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)

```ruby
# Podfile
use_frameworks!

# for app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPCore'
    pod 'AEPEdge'
    pod 'AEPEdgeIdentity'
    pod 'AEPContentAnalytics'
end
```

Replace `YOUR_TARGET_NAME` then run:

```shell
pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

In Xcode, go to `File > Add Packages...` and enter:

`https://github.com/adobe/aca-mobile-sdk-ios-extension.git`

Select your desired version when prompted.

Alternatively, if your project has a `Package.swift` file, you can add AEPContentAnalytics directly to your dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/adobe/aca-mobile-sdk-ios-extension.git", .upToNextMajor(from: "1.0.0"))
],
targets: [
    .target(name: "YourTarget",
            dependencies: ["AEPContentAnalytics"],
            path: "your/path")
]
```

### Binaries

To generate an `AEPContentAnalytics.xcframework`, run the following command:

```shell
$ make archive
```

This generates the xcframework under the `build` folder. Drag and drop all the `.xcframeworks` to your app target in Xcode.

## Development

First time setup:

```shell
make pod-install
```

Update dependencies later:

```shell
make pod-update
```

#### Open workspace

```shell
make open
```

#### Run tests

```shell
make test
```

## Documentation

- **[Getting Started](Documentation/getting-started.md)** - Installation and basic setup
- **[API Reference](Documentation/api-reference.md)** - Complete API documentation
- **[Advanced Configuration](Documentation/advanced-configuration.md)** - Batching, privacy, performance
- **[Troubleshooting](Documentation/troubleshooting.md)** - Common issues and solutions
- **[Validation with Assurance](VALIDATION_WITH_ASSURANCE.md)** - How to validate tracking with Adobe Assurance

## Sample App

A demo application is available in the `SampleApps` directory. See [SampleApps/README.md](SampleApps/README.md) for setup instructions.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Licensing

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for more information.

---

Copyright 2025 Adobe. All rights reserved.
