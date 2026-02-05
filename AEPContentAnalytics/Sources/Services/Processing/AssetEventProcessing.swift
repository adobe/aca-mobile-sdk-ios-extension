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

/// Protocol for processing asset events and dispatching them to Edge Network
protocol AssetEventProcessing {
    /// Processes a batch of asset events, building XDM and dispatching to Edge
    /// - Parameter events: The asset events to process
    func processAssetEvents(_ events: [Event])
    
    /// Sends a single asset event immediately without batching
    /// - Parameter event: The asset event to send
    func sendAssetEventImmediately(_ event: Event)
}
