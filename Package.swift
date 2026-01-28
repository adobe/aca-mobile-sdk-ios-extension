// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import PackageDescription

let package = Package(
    name: "AEPContentAnalytics",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "AEPContentAnalytics",
            targets: ["AEPContentAnalytics"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/adobe/aepsdk-core-ios.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/adobe/aepsdk-edge-ios.git", .upToNextMajor(from: "5.0.0"))
        // NOTE: aepsdk-testutils-ios v5.0.x is incompatible with AEPCore 5.7.0
        // - FileManager extension missing import Foundation
        // - TestableExtensionRuntime protocol conformance issues
        // Using local copy until Adobe releases compatible version (likely 5.1.x or 6.x)
        // .package(url: "https://github.com/adobe/aepsdk-testutils-ios.git", .upToNextMajor(from: "5.0.0"))
    ],
    targets: [
        .target(
            name: "AEPContentAnalytics",
            dependencies: [
                .product(name: "AEPCore", package: "aepsdk-core-ios"),
                .product(name: "AEPServices", package: "aepsdk-core-ios"),
                .product(name: "AEPEdge", package: "aepsdk-edge-ios")
            ],
            path: "AEPContentAnalytics/Sources"
        ),
        .testTarget(
            name: "AEPContentAnalyticsTests",
            dependencies: [
                "AEPContentAnalytics"
                // .product(name: "AEPTestUtils", package: "aepsdk-testutils-ios")  // Incompatible with AEPCore 5.7.0
            ],
            path: "AEPContentAnalytics/Tests"
        )
    ]
)
