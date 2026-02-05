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

/// Protocol for validating privacy status
protocol PrivacyValidator {
    func isDataCollectionAllowed() -> Bool
}

/// Enhanced privacy validator that checks both extension state and global privacy settings
/// Optimized with cached shared states that are updated when they change
class StatePrivacyValidator: PrivacyValidator {
    private let state: ContentAnalyticsStateManager
    private let runtime: ExtensionRuntime

    // Cached shared states for performance optimization
    private let cacheQueue = DispatchQueue(label: "com.adobe.contentanalytics.privacyvalidator.cache")
    private var cachedHubData: [String: Any]?
    private var cachedConsentData: [String: Any]?
    private var cachedIsConsentRegistered: Bool = false
    private var isCacheInitialized: Bool = false

    init(state: ContentAnalyticsStateManager, runtime: ExtensionRuntime) {
        self.state = state
        self.runtime = runtime
    }

    /// Updates the cached shared states from the runtime.
    /// Should be called when Hub or Consent shared state change events are received.
    func updateSharedStateCache() {
        cacheQueue.async { [weak self] in
            self?.refreshCacheSync()
        }
    }

    /// Internal method to refresh cache synchronously
    private func refreshCacheSync() {
        // Fetch Hub shared state
        let hubSharedState = runtime.getSharedState(
            extensionName: ContentAnalyticsConstants.ExternalExtensions.EVENT_HUB,
            event: nil,
            barrier: false,
            resolution: .any
        )

        cachedHubData = hubSharedState?.value

        // Check if Consent extension is registered
        if let hubData = cachedHubData,
           let extensions = hubData[ContentAnalyticsConstants.HubSharedState.EXTENSIONS_KEY] as? [String: Any],
           extensions[ContentAnalyticsConstants.ExternalExtensions.CONSENT] as? [String: Any] != nil {
            cachedIsConsentRegistered = true

            // Fetch Consent XDM shared state (Consent extension publishes XDM, not standard)
            let consentSharedState = runtime.getXDMSharedState(
                extensionName: ContentAnalyticsConstants.ExternalExtensions.CONSENT,
                event: nil,
                barrier: false
            )
            cachedConsentData = consentSharedState?.value
        } else {
            cachedIsConsentRegistered = false
            cachedConsentData = nil
        }

        isCacheInitialized = true

        Log.trace(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Shared state cache updated - Consent registered: \(cachedIsConsentRegistered)")
    }

    func isDataCollectionAllowed() -> Bool {
        return cacheQueue.sync {
            // Lazy initialize cache on first access (important for tests that set mock states after init)
            if !isCacheInitialized {
                refreshCacheSync()
                isCacheInitialized = true
            }

            Log.trace(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "🔒 Starting privacy validation (using cached states)")

            // Check if Hub shared state is available
            guard cachedHubData != nil else {
                Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "No Hub shared state available, blocking data collection (waiting for SDK init)")
                return false
            }

            Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "🔍 Consent extension registered: \(cachedIsConsentRegistered)")

            if cachedIsConsentRegistered {
                // Consent is registered - check its shared state
                guard let consentData = cachedConsentData else {
                    Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Consent extension registered but no shared state yet - assuming pending, blocking data collection")
                    return false
                }

                Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "🔍 Consent shared state data: \(consentData)")

                // Consent shared state exists - use that value
                if let consents = consentData["consents"] as? [String: Any],
                   let collect = consents["collect"] as? [String: Any],
                   let val = collect["val"] as? String {

                    Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "🔍 Consent collect value: \(val)")

                    switch val.lowercased() {
                    case "y", "yes":
                        Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Data collection allowed - consent granted")
                        return true
                    case "n", "no":
                        Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "🚫 Data collection blocked - consent denied")
                        return false
                    case "p", "pending":
                        Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Data collection blocked - consent pending")
                        return false
                    default:
                        Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Data collection blocked - unrecognized consent value: \(val)")
                        return false
                    }
                }

                // Consent data malformed - block
                Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Data collection blocked - malformed consent data")
                return false
            } else {
                // Consent is not registered - assume yes
                Log.debug(label: ContentAnalyticsConstants.LogLabels.PRIVACY_VALIDATOR, "Data collection allowed - Consent extension not registered, assuming yes")
                return true
            }
        }
    }
}
