//
//  ProductRow.swift
//  Luma
//
//  Created by Rob In der Maur on 27/05/2022.
//

import SwiftUI

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        NavigationLink(destination: ProductView(product: product)) {
            HStack {
                // Track product list thumbnails as individual assets
                TrackedAsyncImage(
                    url: URL(string: product.imageURL)!,
                    imageLocation: "products/list",
                    imageType: "product-thumbnail",
                    content: { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50.0)
                    },
                    placeholder: {
                        ProgressView()
                    }
                )
                .cornerRadius(5)
                Text(product.name)
                Spacer()
                if product.featured == true {
                    Image(systemName: "star.fill")
                }
            }
        }
    }
}

struct ProductRow_Previews: PreviewProvider {
    static var previews: some View {
        ProductRow(product: Product.example)
    }
}
