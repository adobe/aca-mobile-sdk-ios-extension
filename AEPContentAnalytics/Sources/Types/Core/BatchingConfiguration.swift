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

/// Configuration for batching behavior (used for both assets and experiences)
///
/// Note: ContentAnalytics only batches Edge Network events by design.
/// There is no need for an event type filter - all events are Edge events.
struct BatchingConfiguration {
    let maxBatchSize: Int
    let flushInterval: TimeInterval
    let maxWaitTime: TimeInterval

    static let `default` = BatchingConfiguration(
        maxBatchSize: 10,
        flushInterval: 2.0,
        maxWaitTime: 5.0
    )
}
