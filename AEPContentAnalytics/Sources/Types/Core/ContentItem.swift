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

import AEPServices
import Foundation

/// Unified content item structure for assets, texts, and CTAs
/// Follows the pattern: {value: "", styles: {}}
@objc(AEPContentItem)
public class ContentItem: NSObject, Codable {
    /// The content value (URL for assets, text for text/CTAs)
    public let value: String

    /// Style metadata for the content item
    public let styles: [String: Any]

    /// Initialize a content item
    /// - Parameters:
    ///   - value: The content value
    ///   - styles: Style metadata dictionary (optional)
    public init(value: String, styles: [String: Any] = [:]) {
        self.value = value
        self.styles = styles
        super.init()
    }

    /// Objective-C compatible initializer
    /// - Parameters:
    ///   - value: The content value
    ///   - styles: Style metadata dictionary (optional)
    @objc
    public convenience init(value: String, stylesDict: [String: Any]?) {
        self.init(value: value, styles: stylesDict ?? [:])
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case value
        case styles
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(String.self, forKey: .value)

        // Decode styles as [String: Any]
        if let stylesData = try? container.decode([String: AnyCodable].self, forKey: .styles) {
            styles = stylesData.mapValues { $0.value }
        } else {
            styles = [:]
        }

        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)

        // Encode styles
        let stylesAnyCodable = styles.mapValues { AnyCodable($0) }
        try container.encode(stylesAnyCodable, forKey: .styles)
    }

    // MARK: - Dictionary Conversion

    /// Convert to dictionary for serialization
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["value": value]
        if !styles.isEmpty {
            dict["style"] = styles // Note: "style" (singular) for payload
        }
        return dict
    }

    /// Create from dictionary
    public static func from(dictionary: [String: Any]) -> ContentItem? {
        guard let value = dictionary["value"] as? String else {
            return nil
        }
        let styles = dictionary["style"] as? [String: Any] ?? [:]
        return ContentItem(value: value, styles: styles)
    }

    // MARK: - NSObject

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ContentItem else { return false }
        return value == other.value && NSDictionary(dictionary: styles).isEqual(to: other.styles)
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(value)
        hasher.combine(NSDictionary(dictionary: styles))
        return hasher.finalize()
    }
}
