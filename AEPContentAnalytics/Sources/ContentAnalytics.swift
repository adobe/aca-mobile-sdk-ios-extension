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

/// ContentAnalytics extension for tracking assets and experiences.
///
/// Captures asset views/clicks and experience interactions, batches events for efficiency,
/// and sends data to Adobe Experience Platform Edge Network. Respects user consent via
/// the Consent extension.
@objc(AEPContentAnalytics)
public class ContentAnalytics: NSObject, Extension {

    public let runtime: ExtensionRuntime
    public let name = ContentAnalyticsConstants.EXTENSION_NAME
    public let friendlyName = ContentAnalyticsConstants.FRIENDLY_NAME
    public static var extensionVersion = ContentAnalyticsConstants.EXTENSION_VERSION
    public var version: String { Self.extensionVersion }
    public let metadata: [String: String]? = nil

    // MARK: - Internal Properties

    private let contentAnalyticsState: ContentAnalyticsStateManager
    private let contentAnalyticsOrchestrator: ContentAnalyticsOrchestrator
    private let privacyValidator: StatePrivacyValidator
    private let factory: ContentAnalyticsFactory

    // MARK: - Initialization

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        self.contentAnalyticsState = ContentAnalyticsStateManager()

        // Initialize with default configuration BEFORE creating factory
        let defaultConfig = ContentAnalyticsConfiguration()
        self.contentAnalyticsState.updateConfiguration(defaultConfig)

        // Create privacy validator that will be shared with orchestrator
        self.privacyValidator = StatePrivacyValidator(state: contentAnalyticsState, runtime: runtime)

        self.factory = ContentAnalyticsFactory(extensionRuntime: runtime, state: contentAnalyticsState, privacyValidator: privacyValidator)
        self.contentAnalyticsOrchestrator = factory.createContentAnalyticsOrchestrator()

        super.init()
    }

    // MARK: - Extension Lifecycle

    @objc public func onRegistered() {
        registerEventListeners()

        // Try to read config from shared state immediately instead of waiting for the first config event
        // (default config already initialized in init())
        if let configSharedState = getConfigurationSharedState(for: nil),
           configSharedState.status == .set,
           let configData = configSharedState.value {
            Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Reading initial configuration from shared state")
            if let config = parseConfiguration(from: configData) {
                contentAnalyticsState.updateConfiguration(config)
                contentAnalyticsOrchestrator.updateConfiguration(config)
            }
        }

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "ContentAnalytics extension registered")
    }

    public func onUnregistered() {
        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "ContentAnalytics extension unregistered")
    }

    // MARK: - Event Listeners

    private func registerEventListeners() {
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationResponse)
        registerListener(type: ContentAnalyticsConstants.EventType.contentAnalytics, source: EventSource.requestContent, listener: handleContentAnalyticsEvent)
        registerListener(type: EventType.edgeConsent, source: EventSource.responseContent, listener: handleConsentChange)
        registerListener(type: EventType.genericIdentity, source: EventSource.requestReset, listener: handleIdentityReset)

        // Listen for shared state changes to update privacy validator cache
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleSharedStateChange)

        // Flush pending batch when app backgrounds (Lifecycle dispatches "Application Close (Background)" on background)
        registerListener(type: EventType.lifecycle, source: EventSource.applicationClose, listener: handleApplicationPauseOrClose)
    }

    // MARK: - Event Handling

    private func handleConfigurationResponse(event: Event) {
        guard let configurationData = event.data else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Configuration event has no data")
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "Received configuration")

        if let config = parseConfiguration(from: configurationData) {
            contentAnalyticsState.updateConfiguration(config)
            contentAnalyticsOrchestrator.updateConfiguration(config)
            Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Config applied")

            if !contentAnalyticsOrchestrator.hasFeaturizationQueue() {
                let newQueue = factory.createFeaturizationHitQueue()
                contentAnalyticsOrchestrator.initializeFeaturizationQueueIfNeeded(queue: newQueue)
            }
        } else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Invalid config data")
        }
    }

    private func handleSharedStateChange(event: Event) {
        // Check if this is a Hub or Consent shared state change
        guard let stateOwner = event.data?["stateowner"] as? String else {
            return
        }

        // Update privacy validator cache when Hub or Consent shared states change
        if stateOwner == ContentAnalyticsConstants.ExternalExtensions.EVENT_HUB ||
           stateOwner == ContentAnalyticsConstants.ExternalExtensions.CONSENT {
            Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "Shared state changed for \(stateOwner) - updating privacy validator cache")
            privacyValidator.updateSharedStateCache()
        }
    }

    private func handleConsentChange(event: Event) {
        guard let consentData = event.data else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Consent event has no data")
            return
        }

        // Check for collect consent preference (Edge will drop events if collect = "no")
        if let consents = consentData["consents"] as? [String: Any],
           let collect = consents["collect"] as? [String: Any],
           let val = collect["val"] as? String {

            Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Consent collect preference: \(val)")

            // Clear pending events if user opts out (Edge would drop them anyway)
            if val == "n" || val == "no" {
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Collect consent denied - clearing pending batch")
                contentAnalyticsOrchestrator.clearPendingBatch()
            }
        }
    }

    private func handleIdentityReset(event: Event) {
        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Identity reset - clearing state")

        // Clear state (configuration, sent experience definitions)
        contentAnalyticsState.reset()

        // Flush any pending batch (don't send after identity reset)
        contentAnalyticsOrchestrator.clearPendingBatch()

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Identity reset complete")
    }

    // MARK: - Event Handler

    private func handleContentAnalyticsEvent(event: Event) {
        Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "Received event | Name: \(event.name) | ID: \(event.id) | Type: \(event.type) | Data: \(event.data ?? [:])")

        // Route to appropriate handler (consent checked by Edge extension)
        if event.isExperienceEvent {
            Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "Routing to experience tracking")
            handleExperienceTrackingEvent(event)
        } else if event.isAssetEvent {
            Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "Routing to asset tracking")
            handleAssetTrackingEvent(event)
        } else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Unknown event: \(event.name)")
        }
    }

    private func handleAssetTrackingEvent(_ event: Event) {
        contentAnalyticsOrchestrator.processAssetEvent(event) { result in
            switch result {
            case .success:
                if let assetURL = event.assetURL {
                    Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Asset event: \(event.name) - \(assetURL)")
                }
            case .failure(let error):
                Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Asset event processing failed: \(event.name) - \(error)")
            }
        }
    }

    private func handleExperienceTrackingEvent(_ event: Event) {
        contentAnalyticsOrchestrator.processExperienceEvent(event) { result in
            switch result {
            case .success:
                if let experienceId = event.experienceId {
                    Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Experience event: \(event.name) - \(experienceId)")
                }
            case .failure(let error):
                Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Experience event processing failed: \(event.name) - \(error)")
            }
        }
    }

    private func handleApplicationPauseOrClose(event: Event) {
        // Only flush if batching is enabled (otherwise events are sent immediately)
        guard contentAnalyticsState.batchingEnabled else {
            Log.trace(label: ContentAnalyticsConstants.LOG_TAG, "App backgrounded but batching disabled - no flush needed")
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "App backgrounded - flushing pending batch")

        contentAnalyticsOrchestrator.sendPendingEvents()

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Background flush complete")
    }

    // MARK: - Helpers

    private func getConfigurationSharedState(for event: Event?) -> SharedStateResult? {
        return getSharedState(extensionName: ContentAnalyticsConstants.ExternalExtensions.CONFIGURATION, event: event)
    }

    // MARK: - Configuration Parsing

    private func parseConfiguration(from configData: [String: Any]) -> ContentAnalyticsConfiguration? {
        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Parsing configuration | Keys: \(configData.keys)")

        // Map Adobe standard keys to ContentAnalytics property names
        var mappedConfig: [String: Any] = [:]

        for (key, value) in configData {
            // Strip "contentanalytics." prefix
            let strippedKey = key.hasPrefix("contentanalytics.")
                ? String(key.dropFirst("contentanalytics.".count))
                : key

            // Map standard Adobe keys to property names
            let mappedKey: String
            switch strippedKey {
            case "edge.domain":
                mappedKey = "edgeDomain"
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Mapped: edge.domain -> edgeDomain = \(value)")
            case "edge.configId":
                // Skip edge.configId - it's for the main app, not Content Analytics
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Skipping: edge.configId (main app datastream)")
                continue
            case "configId":
                // contentanalytics.configId → datastreamId (aligns with edge.configId naming)
                mappedKey = "datastreamId"
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Mapped: contentanalytics.configId -> datastreamId = \(value)")
            case "edge.environment":
                mappedKey = "edgeEnvironment"
            case "experienceCloud.org":
                mappedKey = "experienceCloudOrgId"
                Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Mapped: experienceCloud.org -> experienceCloudOrgId = \(value)")
            default:
                mappedKey = strippedKey
            }

            mappedConfig[mappedKey] = value
        }

        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Mapped config keys: \(mappedConfig.keys)")

        // Convert to JSON data and decode
        guard let jsonData = try? JSONSerialization.data(withJSONObject: mappedConfig),
              let config = try? JSONDecoder().decode(ContentAnalyticsConfiguration.self, from: jsonData) else {
            Log.warning(label: ContentAnalyticsConstants.LOG_TAG, "Failed to decode configuration")
            return nil
        }

        let configSummary = "trackExperiences: \(config.trackExperiences) | edgeDomain: \(config.edgeDomain ?? "nil") | org: \(config.experienceCloudOrgId ?? "nil")"
        Log.debug(label: ContentAnalyticsConstants.LOG_TAG, "Config parsed | \(configSummary) | datastream: \(config.datastreamId ?? "nil")")

        return config
    }

    // MARK: - Extension Readiness

    @objc public func readyForEvent(_ event: Event) -> Bool {
        // For configuration events, always allow them through
        if event.type == EventType.configuration {
            return true
        }

        // For other events, check if configuration shared state is available
        return getConfigurationSharedState(for: event)?.status == .set
    }
}
