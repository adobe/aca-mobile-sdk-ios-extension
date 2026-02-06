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

/// Constants for the ContentAnalytics extension (internal use only)
enum ContentAnalyticsConstants {
    /// Extension name
    static let EXTENSION_NAME = "com.adobe.contentanalytics"

    /// DataStore name
    static let DATASTORE_NAME = EXTENSION_NAME

    static let FEATURIZATION_QUEUE_NAME = "com.adobe.module.contentanalytics.featurization"
    static let ASSET_BATCH_QUEUE_NAME = "com.adobe.module.contentanalytics.assetbatch"
    static let EXPERIENCE_BATCH_QUEUE_NAME = "com.adobe.module.contentanalytics.experiencebatch"
    static let MAX_EXPERIENCE_DEFINITIONS_IN_MEMORY = 100
    
    // MARK: - Batching Configuration Limits
    
    /// Default batch size (events per batch)
    static let DEFAULT_BATCH_SIZE = 10
    
    /// Minimum allowed batch size
    static let MIN_BATCH_SIZE = 1
    
    /// Maximum allowed batch size
    static let MAX_BATCH_SIZE = 100
    
    /// Default batch flush interval (seconds)
    static let DEFAULT_FLUSH_INTERVAL: TimeInterval = 2.0
    
    /// Default maximum wait time (seconds)
    static let DEFAULT_MAX_WAIT_TIME: TimeInterval = 5.0
    
    /// Multiplier for calculating max wait time from flush interval
    static let MAX_WAIT_TIME_MULTIPLIER: Double = 2.5

    /// Extension version
    static let EXTENSION_VERSION = "5.0.0"

    /// Extension friendly name
    static let FRIENDLY_NAME = "Content Analytics"

    /// Log tag for the extension
    static let LOG_TAG = FRIENDLY_NAME

    /// Log labels for filtering and debugging
    enum LogLabels {
        static let EXTENSION = "ContentAnalytics"
        static let ORCHESTRATOR = "ContentAnalytics.Orchestrator"
        static let STATE_MANAGER = "ContentAnalytics.StateManager"
        static let XDM_BUILDER = "ContentAnalytics.XDMBuilder"
        static let BATCH_PROCESSOR = "ContentAnalytics.BatchCoordinator"
        static let PRIVACY_VALIDATOR = "ContentAnalytics.PrivacyValidator"
        static let CONFIG = "ContentAnalytics.Config"
        static let EVENT_VALIDATOR = "ContentAnalytics.EventValidator"
        static let EXCLUSION_FILTER = "ContentAnalytics.ExclusionFilter"
        static let METRICS_BUILDER = "ContentAnalytics.MetricsBuilder"
        static let ASSET_PROCESSOR = "ContentAnalytics.AssetProcessor"
        static let EXPERIENCE_PROCESSOR = "ContentAnalytics.ExperienceProcessor"
    }

    /// Event names
    enum EventNames {
        // Public API events (dispatched from ContentAnalytics+PublicAPI for internal routing)
        static let TRACK_ASSET = "Track Asset"
        static let TRACK_EXPERIENCE = "Track Experience"

        // Edge Network events (dispatched to Adobe Experience Platform)
        static let CONTENT_ANALYTICS_ASSET = "Content Analytics Asset"
        static let CONTENT_ANALYTICS_EXPERIENCE = "Content Analytics Experience"
    }

    /// Type-safe event data field keys
    enum EventDataKeys {
        // Asset tracking
        static let assetURL = "assetURL"
        static let assetLocation = "assetLocation"
        static let assetAction = "action"
        static let assetExtras = "assetExtras"

        // Experience tracking
        static let experienceId = "experienceId"
        static let experienceLocation = "experienceLocation"
        static let experienceAction = "action"
        static let experienceDefinition = "experienceDefinition"
        static let experienceExtras = "experienceExtras"

        // Experience definition
        static let assets = "assets"
        static let texts = "texts"
        static let ctas = "ctas"

        // ContentItem
        static let value = "value"
        static let type = "type"
    }

    /// Event Type constants for ContentAnalytics
    enum EventType {
        /// ContentAnalytics event type - used for internal SDK routing (both asset and experience tracking)
        static let contentAnalytics = "com.adobe.eventType.contentAnalytics"

        /// XDM event type sent to Adobe Experience Platform Edge Network for content engagement
        static let xdmContentEngagement = "content.contentEngagement"
    }

    /// Event source constants
    enum EventSource {
        /// Request content source
        static let requestContent = "com.adobe.eventSource.requestContent"
    }

    /// Featurization service constants
    enum Featurization {
        /// Channel for mobile applications
        static let CHANNEL_MOBILE = "mobile"
    }

    /// Entity types for content tracking
    enum EntityType {
        /// Asset entity type
        static let asset = "asset"

        /// Experience entity type
        static let experience = "experience"
    }

    /// External extension names used by ContentAnalytics
    enum ExternalExtensions {
        /// Configuration extension name
        static let CONFIGURATION = "com.adobe.module.configuration"

        /// Consent extension name
        static let CONSENT = "com.adobe.edge.consent"

        /// Event Hub extension name
        static let EVENT_HUB = "com.adobe.module.eventhub"
    }

    /// Hub shared state keys
    enum HubSharedState {
        /// Key for extensions in hub shared state
        static let EXTENSIONS_KEY = "extensions"
    }
}
