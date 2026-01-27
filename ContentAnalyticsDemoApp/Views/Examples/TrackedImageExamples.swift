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
import AEPContentAnalytics

/// Examples of how to use TrackedAsyncImage in different scenarios
struct TrackedImageExamples: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // MARK: - Simple Usage
                VStack(alignment: .leading, spacing: 10) {
                    Text("Simple Usage")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("TrackedAsyncImage automatically tracks views and clicks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TrackedAsyncImage(
                        url: URL(string: "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg")!,
                        imageLocation: "examples/simple",
                        imageType: "product",
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        },
                        placeholder: {
                            ProgressView()
                        }
                    )
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // MARK: - Product Card Usage
                VStack(alignment: .leading, spacing: 10) {
                    Text("Product Card")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Track product images in catalog")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TrackedAsyncImage(
                        url: URL(string: "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg")!,
                        imageLocation: "examples/product-card",
                        imageType: "product-hero",
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        },
                        placeholder: {
                            ProgressView()
                        }
                    )
                    .frame(width: 180, height: 180)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                }
                
                // MARK: - Custom Styling
                VStack(alignment: .leading, spacing: 10) {
                    Text("Custom Styling")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Custom content rendering with gradient overlay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TrackedAsyncImage(
                        url: URL(string: "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg")!,
                        imageLocation: "examples/hero",
                        imageType: "hero-banner",
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.3)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        },
                        placeholder: {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .frame(width: 250, height: 150)
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                
                // MARK: - Gallery Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("Image Gallery")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Multiple images with automatic tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        ForEach(Array(sampleImageURLs.enumerated()), id: \.offset) { index, imageURL in
                            TrackedAsyncImage(
                                url: URL(string: imageURL)!,
                                imageLocation: "examples/gallery/position-\(index)",
                                imageType: "gallery-item",
                                content: { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                },
                                placeholder: {
                                    ProgressView()
                                }
                            )
                            .frame(width: 120, height: 120)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // MARK: - Banner Image
                VStack(alignment: .leading, spacing: 10) {
                    Text("Banner Image")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Track banner placement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    TrackedAsyncImage(
                        url: URL(string: "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg")!,
                        imageLocation: "examples/banner/top",
                        imageType: "promo-banner",
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        },
                        placeholder: {
                            ProgressView()
                        }
                    )
                    .frame(width: 160, height: 160)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Tracked Images")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // Sample image URLs for the gallery - using working URLs
    private let sampleImageURLs = [
        "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg",
        "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg",
        "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg",
        "https://luma.enablementadobe.com/content/dam/luma/en/products/women/tops/hoodies-&-sweatshirts/wh03-red_main.jpg"
    ]
}

#Preview {
    NavigationView {
        TrackedImageExamples()
    }
} 