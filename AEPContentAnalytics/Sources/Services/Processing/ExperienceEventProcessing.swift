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

/// Protocol for processing experience events and dispatching them to Edge Network
protocol ExperienceEventProcessing {
    /// Processes a batch of experience events, handling definitions and dispatching interactions to Edge
    /// - Parameter events: The experience events to process
    func processExperienceEvents(_ events: [Event])
    
    /// Sends a single experience event immediately without batching
    /// - Parameter event: The experience event to send
    func sendExperienceEventImmediately(_ event: Event)
}
