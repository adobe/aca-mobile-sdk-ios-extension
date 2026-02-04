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

class ConfigurationManager: ConfigurationManaging {
    
    private let queue = DispatchQueue(label: "com.adobe.contentanalytics.configmanager", qos: .userInitiated)
    private var configuration: ContentAnalyticsConfiguration?
    
    init() {}
    
    func updateConfiguration(_ config: ContentAnalyticsConfiguration) {
        queue.sync {
            self.configuration = config
        }
    }
    
    func getCurrentConfiguration() -> ContentAnalyticsConfiguration? {
        return queue.sync {
            return configuration
        }
    }
    
    var batchingEnabled: Bool {
        return queue.sync {
            return configuration?.batchingEnabled ?? false
        }
    }
    
    private func shouldTrack<T>(
        _ value: T?,
        using validator: (ContentAnalyticsConfiguration, T) -> Bool
    ) -> Bool {
        return queue.sync {
            guard let config = configuration else { return true }
            guard let val = value else { return true }
            return validator(config, val)
        }
    }
    
    func shouldTrackUrl(_ url: URL) -> Bool {
        shouldTrack(url, using: { !$0.shouldExcludeUrl($1) })
    }
    
    func shouldTrackExperience(location: String?) -> Bool {
        shouldTrack(location, using: { !$0.shouldExcludeExperience(location: $1) })
    }
    
    func shouldTrackAssetLocation(_ location: String?) -> Bool {
        shouldTrack(location, using: { !$0.shouldExcludeAsset(location: $1) })
    }
    
    func reset() {
        queue.sync {
            configuration = nil
        }
    }
}
