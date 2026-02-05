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
import Foundation

/// Protocol defining the orchestration responsibilities for Content Analytics event processing.
/// This protocol enables dependency injection and testability by abstracting the orchestrator interface.
protocol ContentAnalyticsOrchestrating {
    
    // MARK: - Event Processing
    
    /// Processes an asset tracking event.
    /// - Parameters:
    ///   - event: The asset event to process
    ///   - completion: Completion handler with result indicating success or failure
    func processAssetEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void)
    
    /// Processes an experience tracking event.
    /// - Parameters:
    ///   - event: The experience event to process
    ///   - completion: Completion handler with result indicating success or failure
    func processExperienceEvent(_ event: Event, completion: @escaping (Result<Void, ContentAnalyticsError>) -> Void)
    
    // MARK: - Featurization Queue Management
    
    /// Returns whether the featurization queue has been initialized.
    func hasFeaturizationQueue() -> Bool
    
    /// Initializes the featurization queue if not already initialized.
    /// - Parameter queue: The persistent hit queue to use for featurization
    func initializeFeaturizationQueueIfNeeded(queue: PersistentHitQueue?)
    
    // MARK: - Batch Management
    
    /// Forces sending of any pending batched events.
    func sendPendingEvents()
    
    /// Clears pending batched events without sending them.
    func clearPendingBatch()
    
    // MARK: - Configuration
    
    /// Updates the orchestrator configuration.
    /// - Parameter config: The new configuration to apply
    func updateConfiguration(_ config: ContentAnalyticsConfiguration)
    
    // MARK: - Batch Flush Handlers
    
    /// Handles batch flush callback for asset events.
    /// - Parameter events: Array of asset events to process
    func handleAssetBatchFlush(requests events: [Event])
    
    /// Handles batch flush callback for experience events.
    /// - Parameter events: Array of experience events to process
    func handleExperienceBatchFlush(requests events: [Event])
}
