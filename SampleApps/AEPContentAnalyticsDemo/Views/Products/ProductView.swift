//
//  ProductView.swift
//  Luma
//
//  Created by Rob In der Maur on 27/05/2022.
//

import AEPCore
import AEPContentAnalytics
import SwiftUI

struct ProductView: View {
    @AppStorage("currentEcid") private var currentEcid = ""
    @AppStorage("currency") private var currency = "$"
    
    var product: Product
    private let formattedPriceValue = "0.00"
    
    @State private var showAddToCartDialog = false
    @State private var showPurchaseDialog = false
    @State private var showSaveForLaterDialog = false
    
    var body: some View {
        // Wrap product card in aaa TrackedExperienceView (tracks asset + text as one experience)
        TrackedExperienceView(
            experienceId: "product-\(product.sku)",
            experienceLocation: "products/detail",


            assets: [ContentItem(value: product.imageURL, styles: [:])],
            texts: [
                ContentItem(value: product.name, styles: ["role": "headline"]),
                ContentItem(value: product.description, styles: ["role": "body"]),
                ContentItem(value: product.category, styles: ["role": "caption"])
            ],
            ctas: nil  // Buttons tracked separately via toolbar
        ) {
            VStack {
                // Use TrackedAsyncImage to track assets independently
                // Experience event includes asset reference (assetId only, no metrics)
                // Asset event includes metrics (assetViews, assetClicks)
                // CJA correlates via: experience.assets.assetId = assets.assetId
                TrackedAsyncImage(
                    url: URL(string: product.imageURL)!,
                    imageLocation: "products/detail",
                    imageType: "product",
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
                
                Spacer()
                
                if product.featured == true {
                    Text(product.category.replacingOccurrences(of: ":", with: " ‣ "))
                        .font(Font.system(.footnote).smallCaps())
                        .foregroundColor(Color.gray)
                    + Text(" \(Image(systemName: "star.fill"))")
                        .font(Font.system(.footnote).smallCaps())
                    + Text("\n") + Text(product.description)
                }
                else {
                    Text(product.category.replacingOccurrences(of: ":", with: " ‣ "))
                        .font(Font.system(.footnote).smallCaps())
                        .foregroundColor(Color.gray)
                    + Text("\n") + Text(product.description)
                }
            
            Spacer()
            
            HStack {
                Image(systemName: "square.fill")
                    .foregroundColor(Color[product.color])
                
                Spacer()
                Text("\(currency) \(String(format: "%.2f", product.price))")
                    .fontWeight(.bold)
                Spacer()
                if product.size == "xl" {
                    HStack {
                        Text("\(Image(systemName: "x.square.fill")) \(Image(systemName: "l.square.fill"))")
                            .foregroundColor(.primary)
                    }
                }
                else if product.size == "xs" {
                    HStack {
                        Text("\(Image(systemName: "x.square.fill")) \(Image(systemName: "s.square.fill"))")
                            .foregroundColor(.primary)
                    }
                }
                else {
                    HStack {
                        Image(systemName: "\(product.size).square.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Spacer()
            
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            showSaveForLaterDialog.toggle()
                        } label: {
                            Label("", systemImage: "heart")
                        }
                        .alert(isPresented: $showSaveForLaterDialog) {
                            Alert(title: Text("Saved for later"), 
                                  message: Text("Product saved to wishlist"))
                        }
                        
                        Button {
                            showAddToCartDialog.toggle()
                        } label: {
                            Label("", systemImage: "cart.badge.plus")
                        }
                        .alert(isPresented: $showAddToCartDialog) {
                            Alert(title: Text("Added to cart"), 
                                  message: Text("Product added to cart"))
                        }
                        
                        Button {
                            showPurchaseDialog.toggle()
                        } label: {
                            Label("", systemImage: "creditcard")
                        }
                        .alert(isPresented: $showPurchaseDialog) {
                            Alert(title: Text("Purchase"), 
                                  message: Text("Product purchased"))
                        }
                    }
                }
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            }  // End VStack
        }  // End TrackedExperienceView
        .padding()
        .onAppear {
            MobileSDK.shared.sendTrackScreenEvent(stateName: "products:detail:\(product.sku)")
        }
    }
}

struct ProductView_Previews: PreviewProvider {
    static var previews: some View {
        ProductView(product: Product.example)
    }
}
