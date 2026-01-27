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

/// Processes featurization hits with automatic retry following Adobe Edge extension pattern
/// Implements HitProcessing protocol for use with PersistentHitQueue
class FeaturizationHitProcessor: HitProcessing {
    private let featurizationService: ExperienceFeaturizationServiceProtocol
    private var entityRetryIntervalMapping = ThreadSafeDictionary<String, TimeInterval>()

    /// Recoverable HTTP error codes (should retry) - following Edge pattern
    private let recoverableErrorCodes: [Int] = [
        408, // Request Timeout
        429, // Too Many Requests
        502, // Bad Gateway
        503, // Service Unavailable
        504  // Gateway Timeout
    ]

    init(featurizationService: ExperienceFeaturizationServiceProtocol) {
        self.featurizationService = featurizationService
    }

    // MARK: - HitProcessing Protocol

    /// Returns the retry interval for a specific hit entity
    /// - Parameter entity: The data entity to get retry interval for
    /// - Returns: Time interval to wait before retrying, or default 5 seconds
    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return entityRetryIntervalMapping[entity.uniqueIdentifier] ?? 5.0
    }

    /// Processes a featurization hit (check + register if needed)
    /// - Parameters:
    ///   - entity: The data entity containing the FeaturizationHit
    ///   - completion: Completion handler with true to remove from queue, false to retry
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        // Decode the hit from the entity
        guard let hit = decodeFeaturizationHit(from: entity) else {
            // Unrecoverable error - can't decode hit
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Failed to decode featurization hit | Entity: \(entity.uniqueIdentifier) - dropping")
            completion(true) // Remove from queue
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "🔄 Processing featurization hit | ExperienceID: \(hit.experienceId) | Attempt: \(hit.attemptCount + 1)")

        // Check if experience already exists
        checkAndRegisterExperience(hit: hit, entityId: entity.uniqueIdentifier, completion: completion)
    }

    // MARK: - Private Methods

    /// Decodes FeaturizationHit from DataEntity
    private func decodeFeaturizationHit(from entity: DataEntity) -> FeaturizationHit? {
        guard let data = entity.data else { return nil }
        return try? JSONDecoder().decode(FeaturizationHit.self, from: data)
    }

    /// Checks if experience exists, and registers if not
    private func checkAndRegisterExperience(hit: FeaturizationHit, entityId: String, completion: @escaping (Bool) -> Void) {
        // Validate datastreamId is present (required field)
        let datastreamId = hit.content.datastreamId
        guard !datastreamId.isEmpty else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Cannot check experience - datastreamId is empty | ID: \(hit.experienceId)")
            completion(false) // Don't retry - configuration error
            return
        }

        // Check if experience exists (single attempt - PersistentHitQueue handles retries)
        featurizationService.checkExperienceExists(
            experienceId: hit.experienceId,
            imsOrg: hit.imsOrg,
            datastreamId: datastreamId
        ) { [weak self] result in
            guard let self = self else {
                completion(false) // Retry if self deallocated
                return
            }

            switch result {
            case .success(let exists):
                if exists {
                    // Experience already featurized - success!
                    Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                             "✅ Experience already featurized | ID: \(hit.experienceId)")
                    self.entityRetryIntervalMapping[entityId] = nil
                    completion(true) // Remove from queue
                } else {
                    // Experience not featurized - register it
                    Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                             "📝 Experience not featurized, registering | ID: \(hit.experienceId)")
                    self.registerExperience(hit: hit, entityId: entityId, completion: completion)
                }

            case .failure(let error):
                // Check failed - determine if recoverable
                self.handleCheckFailure(error: error, hit: hit, entityId: entityId, completion: completion)
            }
        }
    }

    /// Registers experience with featurization service via JAG Gateway
    private func registerExperience(hit: FeaturizationHit, entityId: String, completion: @escaping (Bool) -> Void) {
        // Validate datastreamId is present (required field)
        let datastreamId = hit.content.datastreamId
        guard !datastreamId.isEmpty else {
            Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "❌ Cannot register experience - datastreamId is empty | ID: \(hit.experienceId)")
            completion(false) // Don't retry - configuration error
            return
        }

        featurizationService.registerExperience(
            experienceId: hit.experienceId,
            imsOrg: hit.imsOrg,
            datastreamId: datastreamId,
            content: hit.content
        ) { [weak self] result in
            guard let self = self else {
                completion(false) // Retry if self deallocated
                return
            }

            switch result {
            case .success:
                // Registration successful
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                         "✅ Experience registered successfully | ID: \(hit.experienceId)")
                self.entityRetryIntervalMapping[entityId] = nil
                completion(true) // Remove from queue

            case .failure(let error):
                // Registration failed - determine if recoverable
                self.handleRegistrationFailure(error: error, hit: hit, entityId: entityId, completion: completion)
            }
        }
    }

    // MARK: - Error Handling

    /// Operation types for different featurization operations
    private enum FeaturizationOperation {
        case register
        case check

        var logContext: String {
            switch self {
            case .register: return "registering"
            case .check: return "checking"
            }
        }
    }

    /// Handles registration failure - determines if recoverable
    private func handleRegistrationFailure(error: Error, hit: FeaturizationHit, entityId: String, completion: @escaping (Bool) -> Void) {
        handleFeaturizationFailure(error: error, hit: hit, entityId: entityId, operation: .register, completion: completion)
    }

    /// Handles check failure - determines if recoverable
    private func handleCheckFailure(error: Error, hit: FeaturizationHit, entityId: String, completion: @escaping (Bool) -> Void) {
        handleFeaturizationFailure(error: error, hit: hit, entityId: entityId, operation: .check, completion: completion)
    }

    /// Common error handling logic for featurization operations
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - hit: The featurization hit being processed
    ///   - entityId: The unique entity identifier for retry tracking
    ///   - operation: The type of operation (register or check)
    ///   - completion: Completion handler with true to remove from queue, false to retry
    private func handleFeaturizationFailure(
        error: Error,
        hit: FeaturizationHit,
        entityId: String,
        operation: FeaturizationOperation,
        completion: @escaping (Bool) -> Void
    ) {
        // Check if it's a FeaturizationError with HTTP status
        if let featurizationError = error as? FeaturizationError,
           case .httpError(let statusCode) = featurizationError {

            // Special case: 404 on check means experience not featurized yet - register it
            if statusCode == 404 && operation == .check {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                         "📝 404 response - registering experience | ID: \(hit.experienceId)")
                registerExperience(hit: hit, entityId: entityId, completion: completion)
                return
            }

            // Check if error is recoverable
            if recoverableErrorCodes.contains(statusCode) {
                // Recoverable error - retry with exponential backoff
                retryWithBackoff(hit: hit, entityId: entityId, statusCode: statusCode, operation: operation, completion: completion)
            } else {
                // Unrecoverable HTTP error (4xx client errors)
                dropHit(entityId: entityId, statusCode: statusCode, experienceId: hit.experienceId, operation: operation, completion: completion)
            }
        } else {
            // Network error or timeout - recoverable, retry
            retryWithBackoff(hit: hit, entityId: entityId, error: error, operation: operation, completion: completion)
        }
    }

    /// Retry hit with exponential backoff
    private func retryWithBackoff(
        hit: FeaturizationHit,
        entityId: String,
        statusCode: Int? = nil,
        error: Error? = nil,
        operation: FeaturizationOperation,
        completion: @escaping (Bool) -> Void
    ) {
        let retryInterval = calculateRetryInterval(attemptCount: hit.attemptCount)

        if let statusCode = statusCode {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ Recoverable error \(operation.logContext) (\(statusCode)) | ID: \(hit.experienceId) | Retry in: \(retryInterval)s")
        } else if let error = error {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ Network error \(operation.logContext) | ID: \(hit.experienceId) | Error: \(error.localizedDescription) | Retry in: \(retryInterval)s")
        }

        entityRetryIntervalMapping[entityId] = retryInterval
        completion(false) // Keep in queue for retry
    }

    /// Drop hit from queue (unrecoverable error)
    private func dropHit(
        entityId: String,
        statusCode: Int,
        experienceId: String,
        operation: FeaturizationOperation,
        completion: @escaping (Bool) -> Void
    ) {
        Log.error(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "❌ Unrecoverable HTTP error \(operation.logContext) (\(statusCode)) | ID: \(experienceId) - dropping")
        entityRetryIntervalMapping[entityId] = nil
        completion(true) // Remove from queue
    }

    /// Calculates retry interval with exponential backoff: 5s, 10s, 20s, 40s, 80s, caps at 5 minutes
    private func calculateRetryInterval(attemptCount: Int) -> TimeInterval {
        let baseInterval: TimeInterval = 5.0
        let maxInterval: TimeInterval = 300.0 // 5 minutes

        let exponentialInterval = baseInterval * pow(2.0, Double(attemptCount))
        return min(exponentialInterval, maxInterval)
    }
}
