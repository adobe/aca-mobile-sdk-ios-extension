//
//  TrackedExperienceView.swift
//  Luma
//
//  Tracks complete experiences with images, text, and buttons using the latest ContentAnalytics API
//

import SwiftUI
import AEPCore
import AEPContentAnalytics

/// A view wrapper that automatically tracks experiences (image + text + buttons) to Adobe Experience Platform
/// Uses the "register once, track many" pattern for optimal performance
struct TrackedExperienceView<Content: View>: View {
    let experienceId: String
    let experienceLocation: String
    let assets: [ContentItem]
    let texts: [ContentItem]
    let ctas: [ContentItem]?
    let content: () -> Content
    
    @State private var hasAppeared = false
    @State private var registeredExperienceId: String?
    
    init(
        experienceId: String,
        experienceLocation: String,
        assets: [ContentItem],
        texts: [ContentItem],
        ctas: [ContentItem]? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.experienceId = experienceId
        self.experienceLocation = experienceLocation
        self.assets = assets
        self.texts = texts
        self.ctas = ctas
        self.content = content
    }
    
    var body: some View {
        content()
            .onAppear {
                handleAppear()
            }
            .onDisappear {
                handleDisappear()
            }
            .onTapGesture {
                handleClick()
            }
    }
    
    // MARK: - Private Methods
    
    private func handleAppear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        
        // Register the experience ONCE on first appearance
        registerAndTrackView()
    }
    
    private func handleDisappear() {
        guard hasAppeared else { return }
        hasAppeared = false
    }
    
    private func handleClick() {
        // Track click on the experience
        trackClick()
    }
    
    /// Register the experience and track the view (called once on first appearance)
    private func registerAndTrackView() {
        // Register experience (location specified during tracking)
        let returnedId = ContentAnalytics.registerExperience(
            assets: assets,
            texts: texts,
            ctas: ctas
        )
        
        // Store the registered ID for future interactions
        registeredExperienceId = returnedId
        
        // Track the view with the SAME location (key will match registration)
        ContentAnalytics.trackExperienceView(
            experienceId: returnedId,
            experienceLocation: experienceLocation
        )
        
        // Note: Assets should be tracked using TrackedAsyncImage within the experience content.
        // This creates two event types:
        // 1. Experience event with asset references (assetId only, no metrics)
        // 2. Asset events with metrics (assetViews, assetClicks)
        // CJA can correlate these via: experience.assets.assetId = assets.assetId
    }
    
    /// Track a click/tap on this experience
    func trackClick() {
        // If we have a registered ID, use it for tracking
        if let registeredId = registeredExperienceId {
            ContentAnalytics.trackExperienceClick(
                experienceId: registeredId,
                experienceLocation: experienceLocation
            )
        } else {
            // Fallback: register first if not yet registered
            let returnedId = ContentAnalytics.registerExperience(
                assets: assets,
                texts: texts,
                ctas: ctas
            )
            registeredExperienceId = returnedId
            ContentAnalytics.trackExperienceClick(
                experienceId: returnedId,
                experienceLocation: experienceLocation
            )
        }
    }
}

// MARK: - Convenience Initializers for Products

extension TrackedExperienceView {
    /// Convenience initializer for tracking product cards
    init(
        product: Product,
        experienceLocation: String,
        includeButtons: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        let assets = [ContentItem(value: product.imageURL, styles: [:])]
        
        let texts = [
            ContentItem(value: product.name, styles: ["role": "headline"]),
            ContentItem(value: "$\(String(format: "%.2f", product.price))", styles: ["role": "price"]),
            ContentItem(value: product.category, styles: ["role": "caption"])
        ]
        
        let ctas: [ContentItem]? = includeButtons ? [
            ContentItem(value: "View Details", styles: ["enabled": true])
        ] : nil
        
        self.init(
            experienceId: "product-\(product.sku)",
            experienceLocation: experienceLocation,
            assets: assets,
            texts: texts,
            ctas: ctas,
            content: content
        )
    }
}
