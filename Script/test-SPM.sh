#!/bin/bash

set -e

PROJECT_NAME=TestProject

# Clean up.
rm -rf $PROJECT_NAME

mkdir -p $PROJECT_NAME && cd $PROJECT_NAME

# Create the package.
swift package init

# Create Package.swift that depends on AEPContentAnalytics (local path) and its transitive deps.
cat > Package.swift << 'PACKAGE_EOF'
// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "TestProject",
    defaultLocalization: "en-US",
    platforms: [ .iOS(.v15), .tvOS(.v15) ],
    products: [
        .library(name: "TestProject", targets: ["TestProject"])
    ],
    dependencies: [
        .package(name: "AEPContentAnalytics", path: "../")
    ],
    targets: [
        .target(
            name: "TestProject",
            dependencies: [
                .product(name: "AEPContentAnalytics", package: "AEPContentAnalytics")
            ]
        )
    ]
)
PACKAGE_EOF

swift package update
swift package resolve

# Avoid internal PIF error
swift package dump-pif > /dev/null
(xcodebuild clean -scheme TestProject -destination 'generic/platform=iOS' > /dev/null) || true

# Archive for generic iOS device
echo '############# Archive for generic iOS device ###############'
xcodebuild archive -scheme TestProject -destination 'generic/platform=iOS'

# Build for generic iOS device
echo '############# Build for generic iOS device ###############'
xcodebuild build -scheme TestProject -destination 'generic/platform=iOS'

# Build for iOS simulator
echo '############# Build for iOS simulator ###############'
xcodebuild build -scheme TestProject -destination 'generic/platform=iOS Simulator'

# Archive for generic tvOS device
echo '############# Archive for generic tvOS device ###############'
xcodebuild archive -scheme TestProject -destination 'generic/platform=tvOS'

# Build for generic tvOS device
echo '############# Build for generic tvOS device ###############'
xcodebuild build -scheme TestProject -destination 'generic/platform=tvOS'

# Build for tvOS simulator
echo '############# Build for tvOS simulator ###############'
xcodebuild build -scheme TestProject -destination 'generic/platform=tvOS Simulator'

# Clean up.
cd ..
rm -rf $PROJECT_NAME
