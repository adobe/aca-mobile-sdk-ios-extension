//
//  ProductsView.swift
//  ContentAnalytics Demo
//
//  Product catalog demonstrating asset tracking
//

import AEPCore
import SwiftUI

struct ProductsView: View {
    @State private var products = [Product]()
    
    var groupedProducts: [String: [Product]] {
        Dictionary(grouping: products, by: { $0.category })
    }
    
    var featuredProducts: [Product] {
        products.filter { $0.featured == true }.shuffled()
    }
    
    var categories: [String] {
        groupedProducts.map( { $0.key }).sorted().reversed()
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("\(Image(systemName: "star.fill")) Featured")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(featuredProducts, id: \.sku) { product in
                                NavigationLink {
                                    ProductView(product: product)
                                } label: {
                                    VStack(spacing: 8) {
                                        // Track featured product images as individual assets
                                        TrackedAsyncImage(
                                            url: URL(string: product.imageURL)!,
                                            imageLocation: "products/featured",
                                            imageType: "product-thumbnail",
                                            content: { image in
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .cornerRadius(10)
                                            },
                                            placeholder: {
                                                ProgressView()
                                            }
                                        )
                                        .frame(width: 100, height: 100)
                                        
                                        Text(product.name)
                                            .font(.footnote)
                                            .frame(width: 100)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                ForEach(categories, id: \.self) { category in
                    Section(category.replacingOccurrences(of: ":", with: " ‣ ")) {
                        ForEach(products.filter { $0.category == category }) { product in
                            ProductRow(product: product)
                        }
                    }
                }
            }
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.automatic)
        }
        .task {
            loadProducts()
        }
        .onAppear {
            MobileSDK.shared.sendTrackScreenEvent(stateName: "products:view")
        }
    }
    
    func loadProducts() {
        // Load products from local JSON file
        if let url = Bundle.main.url(forResource: "products", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            // JSON has structure: {"products": [...]}
            if let productsWrapper = try? decoder.decode(Products.self, from: data) {
                products = productsWrapper.products
                print("✅ Loaded \(products.count) products from local file")
            } else {
                print("❌ Failed to decode products.json")
            }
        } else {
            print("❌ Could not find products.json in bundle")
        }
    }
}

struct ProductsView_Previews: PreviewProvider {
    static var previews: some View {
        ProductsView()
    }
}
