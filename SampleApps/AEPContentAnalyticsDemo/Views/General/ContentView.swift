//
//  ContentView.swift
//  ContentAnalytics Demo
//
//  Simple tab navigation for ContentAnalytics extension development
//

import AEPCore
import AEPEdgeIdentity
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag("Home")
            
            ProductsView()
                .tabItem {
                    Image(systemName: "cart")
                    Text("Products")
                }
                .tag("Products")
            
            NavigationView {
                TrackedImageExamples()
            }
            .tabItem {
                Image(systemName: "photo.stack")
                Text("Examples")
            }
            .tag("Examples")
            
            ConfigView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Config")
                }
                .tag("Config")
        }
        .onAppear {
            // Get ECID when app launches
            AEPEdgeIdentity.Identity.getExperienceCloudId { ecid, _ in
                if let ecid = ecid {
                    print("🆔 ECID: \(ecid)")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
