/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import SwiftUI
import AEPCore
import AEPContentAnalytics

/// A SwiftUI view that wraps AsyncImage and adds image tracking capabilities
/// using the ContentAnalytics extension
struct TrackedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let imageLocation: String
    let imageType: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var hasAppeared = false
    
    init(url: URL,
         imageLocation: String,
         imageType: String,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.imageLocation = imageLocation
        self.imageType = imageType
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder()
                
            case .success(let image):
                content(image)
                    .onAppear {
                        handleImageAppear()
                    }
                    .onDisappear {
                        handleImageDisappear()
                    }
                    .onTapGesture {
                        handleImageTap()
                    }
                
            case .failure:
                placeholder()
                
            @unknown default:
                placeholder()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleImageAppear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        
        // Track view event using simplified ContentAnalytics API
        ContentAnalytics.trackAsset(
            assetURL: url.absoluteString,
            interactionType: .view,
            assetLocation: imageLocation
        )
    }
    
    private func handleImageDisappear() {
        guard hasAppeared else { return }
        hasAppeared = false
    }
    
    private func handleImageTap() {
        // Track click event using simplified ContentAnalytics API
        ContentAnalytics.trackAsset(
            assetURL: url.absoluteString,
            interactionType: .click,
            assetLocation: imageLocation
        )
    }
}

// MARK: - Convenience Initializers

extension TrackedAsyncImage where Content == AnyView, Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Convenience initializer with default placeholder
    init(url: URL,
         imageLocation: String,
         imageType: String) {
        self.init(
            url: url,
            imageLocation: imageLocation,
            imageType: imageType,
            content: { image in
                AnyView(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
            },
            placeholder: {
                ProgressView()
            }
        )
    }
}
