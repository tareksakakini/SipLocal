/**
 * MenuItemCard.swift
 * SipLocal
 *
 * Reusable card component for displaying menu items in grid layouts.
 * Extracted from MenuItemsView.swift for better organization.
 *
 * ## Features
 * - **Image Display**: AsyncImage with fallback placeholders
 * - **Price Formatting**: Smart price display for items with size variations
 * - **Add Button**: Direct add-to-cart functionality
 * - **Responsive Design**: Fixed dimensions for consistent grid layouts
 * - **Error Handling**: Graceful fallbacks for missing images
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on menu item card display
 * - **Reusable Component**: Can be used in any menu context
 * - **Clean Interface**: Simple callback-based interaction
 * - **Performance**: Optimized image loading and caching
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - MenuItemCard

/**
 * Card component for displaying menu items in grid layouts
 * 
 * Provides a consistent, reusable card design for menu items with
 * image display, pricing, and add-to-cart functionality.
 */
struct MenuItemCard: View {
    
    // MARK: - Properties
    let item: MenuItem
    let shop: CoffeeShop
    let category: String
    let cartManager: CartManager
    var onAdd: (() -> Void)? = nil
    
    // MARK: - Design System
    private enum Design {
        static let cardCornerRadius: CGFloat = 12
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowOpacity: Double = 0.08
        static let imageWidth: CGFloat = 115
        static let imageHeight: CGFloat = 105
        static let contentSpacing: CGFloat = 6
        static let contentPadding: CGFloat = 8
        static let titleHeight: CGFloat = 35
        static let buttonCornerRadius: CGFloat = 8
        static let fallbackIconSize: CGFloat = 40
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            itemImageSection
            
            // Content Section
            itemContentSection
        }
        .background(Color.white)
        .cornerRadius(Design.cardCornerRadius)
        .shadow(
            color: Color.black.opacity(Design.cardShadowOpacity),
            radius: Design.cardShadowRadius,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - View Components
    
    /**
     * Item image section with async loading and fallbacks
     */
    private var itemImageSection: some View {
        Group {
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: Design.imageWidth, height: Design.imageHeight)
                            .clipped()
                    case .failure(_):
                        imageFallbackView
                    case .empty:
                        imageLoadingView
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                imageFallbackView
            }
        }
    }
    
    /**
     * Item content section with title, price, and add button
     */
    private var itemContentSection: some View {
        VStack(spacing: Design.contentSpacing) {
            // Item name
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(.primary)
                .frame(height: Design.titleHeight) // Fixed height to prevent layout shifts
            
            // Price
            Text(formatPrice(for: item))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            // Add button
            addButton
        }
        .padding(Design.contentPadding)
    }
    
    /**
     * Add to cart button
     */
    private var addButton: some View {
        Button(action: {
            onAdd?()
        }) {
            Text("Add")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.black)
                .cornerRadius(Design.buttonCornerRadius)
        }
    }
    
    /**
     * Fallback view for missing or failed images
     */
    private var imageFallbackView: some View {
        VStack {
            Image(systemName: "photo.fill")
                .resizable()
                .scaledToFit()
                .frame(width: Design.fallbackIconSize, height: Design.fallbackIconSize)
                .foregroundColor(.gray)
            
            Text("Image Not Available")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: Design.imageWidth, height: Design.imageHeight)
        .background(Color(.systemGray5))
    }
    
    /**
     * Loading view for async image loading
     */
    private var imageLoadingView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: Design.imageWidth, height: Design.imageHeight)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            )
    }
    
    // MARK: - Helper Methods
    
    /**
     * Format price for display, showing starting price for items with variations
     */
    private func formatPrice(for item: MenuItem) -> String {
        // Always show the smallest size price (starting price)
        if let variations = item.variations, variations.count > 1 {
            let minPrice = variations.map(\.price).min() ?? item.price
            return String(format: "$%.2f", minPrice)
        } else {
            // Single size or no variations - show base price
            return String(format: "$%.2f", item.price)
        }
    }
}

// MARK: - RoundedCorner Extension

/**
 * Extension to add corner radius to specific corners
 */
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/**
 * Custom shape for rounded corners on specific sides
 */
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

struct MenuItemCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = MenuItem(
            id: "sample",
            name: "Sample Coffee",
            price: 4.50,
            variations: [
                MenuItemVariation(id: "small", name: "Small", price: 4.50, ordinal: 1),
                MenuItemVariation(id: "large", name: "Large", price: 5.50, ordinal: 2)
            ],
            customizations: nil,
            imageURL: nil,
            modifierLists: nil
        )
        
        let sampleShop = CoffeeShop(
            id: "sample",
            name: "Sample Shop",
            address: "123 Main St",
            latitude: 0,
            longitude: 0,
            phone: "555-0123",
            website: "https://example.com",
            description: "Sample coffee shop",
            imageName: "sample",
            stampName: "sample_stamp",
            merchantId: "sample_merchant",
            posType: .square
        )
        
        MenuItemCard(
            item: sampleItem,
            shop: sampleShop,
            category: "Coffee",
            cartManager: CartManager(),
            onAdd: { print("Add button tapped") }
        )
        .frame(width: 150, height: 200)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
