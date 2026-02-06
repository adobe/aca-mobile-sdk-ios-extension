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

/// Dispatches events to AEP SDK event hub. Abstracted for testing.
protocol ContentAnalyticsEventDispatcher: AnyObject {
    /// Dispatches an event to the AEP SDK.
    /// - Parameter event: The `Event` to be dispatched.
    func dispatch(event: Event)
}

class EdgeEventDispatcher: ContentAnalyticsEventDispatcher {
    private let runtime: ExtensionRuntime

    init(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    func dispatch(event: Event) {
        Log.debug(label: ContentAnalyticsConstants.LogLabels.EXTENSION, "Dispatching to Edge: \(event.name)")

        runtime.dispatch(event: event)
    }
}
