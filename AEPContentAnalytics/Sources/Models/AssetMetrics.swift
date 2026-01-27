/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

/// Represents aggregated metrics for a single asset
struct AssetMetrics {
    /// The URL of the asset (identifier)
    let assetURL: String

    /// The location where the asset appears (dimension)
    let assetLocation: String

    /// Number of view interactions
    let viewCount: Double

    /// Number of click interactions
    let clickCount: Double

    /// Optional additional metadata for the asset
    let assetExtras: [String: Any]?

    /// Converts this typed model to an event data dictionary
    /// - Returns: A dictionary representation suitable for XDM or event dispatch
    func toEventData() -> [String: Any] {
        var data: [String: Any] = [
            "assetURL": assetURL,
            "assetLocation": assetLocation,
            "viewCount": viewCount,
            "clickCount": clickCount
        ]

        if let extras = assetExtras {
            data[AssetTrackingEventPayload.OptionalFields.assetExtras] = extras
        }

        return data
    }
}

/// Represents aggregated metrics for a collection of assets
struct AssetMetricsCollection {
    /// Map of asset key to metrics
    private let metrics: [String: AssetMetrics]

    init(metrics: [String: AssetMetrics]) {
        self.metrics = metrics
    }

    /// All asset keys in this collection
    var assetKeys: [String] {
        return Array(metrics.keys)
    }

    /// Get metrics for a specific asset key
    func metrics(for key: String) -> AssetMetrics? {
        return metrics[key]
    }

    /// Converts the entire collection to event data format
    /// - Returns: A dictionary mapping asset keys to their metrics
    func toEventData() -> [String: [String: Any]] {
        return metrics.mapValues { $0.toEventData() }
    }

    /// Number of assets in this collection
    var count: Int {
        return metrics.count
    }

    /// Check if collection is empty
    var isEmpty: Bool {
        return metrics.isEmpty
    }
}
