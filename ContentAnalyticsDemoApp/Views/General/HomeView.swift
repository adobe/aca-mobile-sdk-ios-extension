//
//  HomeView.swift
//  ContentAnalytics Demo
//
//  Simple home screen for ContentAnalytics extension development
//

import AEPCore
import AEPEdgeIdentity
import SwiftUI

struct HomeView: View {
    @AppStorage("currentEcid") private var currentEcid = ""
    @AppStorage("brandName") private var brandName = "ContentAnalytics Demo"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(brandName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Adobe Experience Platform")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("ContentAnalytics Extension")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // ECID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Experience Cloud ID")
                            .font(.headline)
                        
                        if currentEcid.isEmpty {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(currentEcid)
                                .font(.caption)
                                .monospaced()
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .onTapGesture {
                                    UIPasteboard.general.string = currentEcid
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // What's tracked
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's Being Tracked")
                            .font(.headline)
                        
                        FeatureRow(icon: "photo", title: "Asset Views & Clicks", 
                                   description: "Individual images in the product catalog")
                        FeatureRow(icon: "rectangle.3.group", title: "Experience Views & Clicks",
                                   description: "Complete experiences with images, text, and buttons")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Automatic Batching",
                                   description: "Events are queued and sent efficiently")
                        FeatureRow(icon: "checkmark.shield", title: "Privacy-First",
                                   description: "Respects user consent preferences")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Get ECID on appear
            AEPEdgeIdentity.Identity.getExperienceCloudId { ecid, _ in
                if let ecid = ecid {
                    currentEcid = ecid
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
