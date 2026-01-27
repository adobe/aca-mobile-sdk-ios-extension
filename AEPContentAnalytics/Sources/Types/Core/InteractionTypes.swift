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

import AEPCore
import Foundation

// MARK: - Interaction Metrics

/// Unified interaction metrics for both assets and experiences
/// Stores aggregated view and click counts
struct InteractionMetrics: Codable {
    var viewCount: Double = 0
    var clickCount: Double = 0
}

// MARK: - Interaction Type

/// Unified interaction type for both assets and experiences
/// Objective-C compatible enum following AEPCore pattern
@objc(AEPInteractionType)
public enum InteractionType: Int, RawRepresentable {
    case definition = 0  // Experience registration (not used for assets)
    case view = 1
    case click = 2

    /// String representation of the interaction type for XDM payloads
    public var stringValue: String {
        switch self {
        case .definition:
            return "definition"
        case .view:
            return "view"
        case .click:
            return "click"
        }
    }

    /// Creates an InteractionType from a string value
    /// - Parameter string: The string representation ("definition", "view", or "click")
    /// - Returns: The corresponding InteractionType or nil if invalid
    public static func from(string: String) -> InteractionType? {
        switch string.lowercased() {
        case "definition":
            return .definition
        case "view":
            return .view
        case "click":
            return .click
        default:
            return nil
        }
    }
}
