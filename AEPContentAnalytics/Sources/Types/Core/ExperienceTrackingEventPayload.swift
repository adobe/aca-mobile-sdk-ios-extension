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

/// Structured types for experience tracking event payloads (internal use only)
enum ExperienceTrackingEventPayload {

    /// Required fields for all experience tracking events
    enum RequiredFields {
        static let experienceId = "experienceId"
        static let interactionType = "interactionType"
    }

    /// Optional fields that can be included in event payloads
    enum OptionalFields {
        static let experienceLocation = "experienceLocation"
        static let assetURLs = "assetURLs"
        static let texts = "texts"  // Changed from textContent to match [{value, style}] format
        static let ctas = "ctas"    // Changed from buttonContent to match [{value, style}] format
        static let experienceExtras = "experienceExtras"
    }
}
