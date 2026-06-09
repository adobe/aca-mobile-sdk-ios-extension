//
//  AppDelegate.swift
//  ContentAnalytics Demo
//
//  Simple app delegate for ContentAnalytics extension development
//

import AEPCore
import AEPServices
import AEPLifecycle
import AEPEdge
import AEPEdgeIdentity
import AEPEdgeConsent
import AEPAssurance
import AEPContentAnalytics
import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let environmentFileId = "staging/b42a0d18ad1d/0d66a105f7d6/launch-6f3548049987-development"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("🚀 ========================================")
        print("🚀 ContentAnalytics Demo App Starting...")
        print("🚀 ========================================")
        
        // Set log level to TRACE for maximum visibility
        MobileCore.setLogLevel(.trace)
        print("📊 Log level set to: TRACE")
        
        let appState = application.applicationState
        print("📱 App state: \(appState == .background ? "background" : "active")")
        
        // Register essential AEP extensions
        let extensions = [
            Lifecycle.self,
            Edge.self,
            AEPEdgeIdentity.Identity.self,
            Consent.self,
            Assurance.self,
            ContentAnalytics.self
        ]
        
        print("📦 Registering \(extensions.count) AEP extensions...")
        
        MobileCore.registerExtensions(extensions) {
            print("✅ ========================================")
            print("✅ SDK Initialization Complete!")
            print("✅ ========================================")
            print("📱 Environment ID: \(self.environmentFileId)")
            
            // Configure with Launch environment
            MobileCore.configureWith(appId: self.environmentFileId)
            print("⚙️  Launch configuration loaded")
            
            
            // Start lifecycle if not in background
            if appState != .background {
                MobileCore.lifecycleStart(additionalContextData: nil)
                print("♻️  Lifecycle started")
            }
            
            // Set consent to opted-in for development
            Consent.update(with: ["consents": ["collect": ["val": "y"]]])
            print("✅ Consent: OPTED IN (development mode)")
            
            // Get and log ECID
            AEPEdgeIdentity.Identity.getExperienceCloudId { ecid, error in
                if let ecid = ecid {
                    print("🆔 ECID: \(ecid)")
                } else if let error = error {
                    print("❌ Error getting ECID: \(error.localizedDescription)")
                }
            }
            
            print("🚀 ========================================")
            print("🚀 App Ready!")
            print("🚀 ========================================")
        }
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Cleanup if needed
    }
}



