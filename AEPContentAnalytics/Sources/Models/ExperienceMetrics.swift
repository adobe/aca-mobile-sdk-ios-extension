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

/// Represents aggregated metrics for a single experience
struct ExperienceMetrics {
    /// The unique identifier for the experience
    let experienceID: String

    /// The location or source where the experience appears (dimension)
    let experienceSource: String

    /// Number of view interactions
    let viewCount: Double

    /// Number of click interactions
    let clickCount: Double

    /// Optional additional metadata for the experience
    let experienceExtras: [String: Any]?

    /// List of asset URLs attributed to this experience
    let attributedAssets: [String]

    /// Converts this typed model to an event data dictionary
    /// - Returns: A dictionary representation suitable for XDM or event dispatch
    func toEventData() -> [String: Any] {
        var data: [String: Any] = [
            "experienceID": experienceID,
            "experienceSource": experienceSource,
            "viewCount": viewCount,
            "clickCount": clickCount,
            "attributedAssets": attributedAssets
        ]

        if let extras = experienceExtras {
            data[ExperienceTrackingEventPayload.OptionalFields.experienceExtras] = extras
        }

        return data
    }
}

/// Represents aggregated metrics for a collection of experiences
struct ExperienceMetricsCollection {
    /// Map of experience key to metrics
    private let metrics: [String: ExperienceMetrics]

    init(metrics: [String: ExperienceMetrics]) {
        self.metrics = metrics
    }

    /// All experience keys in this collection
    var experienceKeys: [String] {
        return Array(metrics.keys)
    }

    /// Get metrics for a specific experience key
    func metrics(for key: String) -> ExperienceMetrics? {
        return metrics[key]
    }

    /// Converts the entire collection to event data format
    /// - Returns: A dictionary mapping experience keys to their metrics
    func toEventData() -> [String: [String: Any]] {
        return metrics.mapValues { $0.toEventData() }
    }

    /// Number of experiences in this collection
    var count: Int {
        return metrics.count
    }

    /// Check if collection is empty
    var isEmpty: Bool {
        return metrics.isEmpty
    }
}
