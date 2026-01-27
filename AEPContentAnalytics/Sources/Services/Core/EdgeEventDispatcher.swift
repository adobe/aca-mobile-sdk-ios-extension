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
import AEPServices

/// A protocol for dispatching events to the Adobe Experience Platform SDK.
///
/// This protocol abstracts the event dispatching mechanism, allowing for different
/// implementations, such as a concrete dispatcher for production use and a mock
/// dispatcher for testing.
protocol ContentAnalyticsEventDispatcher: AnyObject {
    /// Dispatches an event to the AEP SDK.
    /// - Parameter event: The `Event` to be dispatched.
    func dispatch(event: Event)
}

/// A concrete implementation of the `ContentAnalyticsEventDispatcher` protocol.
///
/// This class uses the `ExtensionRuntime` to dispatch events to the AEP SDK's event hub,
/// ensuring that image tracking events are processed by the Adobe Experience Platform Edge Network.
class EdgeEventDispatcher: ContentAnalyticsEventDispatcher {
    private let runtime: ExtensionRuntime

    /// Initializes the dispatcher with the provided extension runtime.
    /// - Parameter runtime: The `ExtensionRuntime` instance from the AEP SDK.
    init(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    /// Dispatches an event to the AEP event hub.
    /// - Parameter event: The `Event` to be dispatched.
    func dispatch(event: Event) {
        Log.debug(label: ContentAnalyticsConstants.LOG_TAG,
                 "→ Edge: \(event.name)")

        runtime.dispatch(event: event)
    }
}
