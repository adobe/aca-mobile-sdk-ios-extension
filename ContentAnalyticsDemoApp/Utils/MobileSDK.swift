//
//  MobileSDK.swift
//  ContentAnalytics Demo
//
//  Simplified helper for ContentAnalytics extension development
//

import AEPCore
import AEPEdge
import AEPEdgeIdentity
import AEPEdgeConsent
import Foundation
import SwiftUI

struct MobileSDK {
    static let shared = MobileSDK()
    
    /// Update consent
    /// - Parameter value: "y" for opted-in, "n" for opted-out
    func updateConsent(value: String) {
        let collectConsent = ["collect": ["val": value]]
        let currentConsents = ["consents": collectConsent]
        Consent.update(with: currentConsents)
        print("✅ Consent updated to: \(value)")
    }
    
    /// Get current consent status
    func getConsents() {
        Consent.getConsents { consents, error in
            guard error == nil, let consents = consents else {
                print("❌ Error getting consents: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: consents, options: .prettyPrinted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                print("📋 Current consents:\n\(jsonStr)")
            }
        }
    }
    
    /// Get Experience Cloud ID
    func getECID(completion: @escaping (String?) -> Void) {
        AEPEdgeIdentity.Identity.getExperienceCloudId { ecid, error in
            if let error = error {
                print("❌ Error getting ECID: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(ecid)
        }
    }
    
    /// Get all identities
    func getIdentities() {
        AEPEdgeIdentity.Identity.getIdentities { identityMap, error in
            if let error = error {
                print("❌ Error getting identities: \(error.localizedDescription)")
                return
            }
            
            if let identityMap = identityMap {
                print("🆔 Identities: \(identityMap)")
            }
        }
    }
    
    /// Send a simple track screen event
    /// - Parameter stateName: The screen/state name
    func sendTrackScreenEvent(stateName: String) {
        let experienceEvent = ExperienceEvent(xdm: ["eventType": "screen.view",
                                                     "state": stateName])
        Edge.sendEvent(experienceEvent: experienceEvent)
        print("📊 Screen view tracked: \(stateName)")
    }
}
