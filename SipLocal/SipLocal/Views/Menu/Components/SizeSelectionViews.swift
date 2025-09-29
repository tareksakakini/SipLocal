/**
 * SizeSelectionViews.swift
 * SipLocal
 *
 * Components for size selection in menu item customization.
 * Extracted from MenuItemsView.swift for better organization.
 *
 * ## Features
 * - **Size Selection Grid**: 3-column grid layout for size options
 * - **Price Display**: Full prices prominently displayed for each size
 * - **Visual Feedback**: Selected state with accent color highlighting
 * - **Responsive Design**: Flexible grid that adapts to content
 * - **Accessibility**: Proper button styling and touch targets
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on size selection UI
 * - **Reusable Components**: Can be used in any customization context
 * - **Clean Interface**: Simple binding-based state management
 * - **Performance**: Efficient grid rendering with LazyVGrid
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - SizeSelectionView

/**
 * Main size selection component with grid layout
 * 
 * Displays size variations in a 3-column grid with prominent price display
 * and visual selection feedback.
 */
struct SizeSelectionView: View {
    
    // MARK: - Properties
    let variations: [MenuItemVariation]
    @Binding var selectedSizeId: String?
    
    // MARK: - Design System
    private enum Design {
        static let titleFont: Font = .headline
        static let titleWeight: Font.Weight = .semibold
        static let spacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let gridColumns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacing) {
            // Section title
            sectionTitle
            
            // Size options grid
            sizeOptionsGrid
        }
        .padding(.horizontal, Design.horizontalPadding)
        .padding(.vertical, Design.verticalPadding)
        .background(Color(.systemGray6))
        .cornerRadius(Design.cornerRadius)
    }
    
    // MARK: - View Components
    
    /**
     * Section title
     */
    private var sectionTitle: some View {
        Text("Size")
            .font(Design.titleFont)
            .fontWeight(Design.titleWeight)
            .foregroundColor(.primary)
    }
    
    /**
     * Grid of size option cards
     */
    private var sizeOptionsGrid: some View {
        LazyVGrid(columns: Design.gridColumns, spacing: Design.spacing) {
            ForEach(variations) { variation in
                SizeOptionCard(
                    variation: variation,
                    isSelected: selectedSizeId == variation.id,
                    onTap: {
                        selectedSizeId = variation.id
                    }
                )
            }
        }
    }
}

// MARK: - SizeOptionCard

/**
 * Individual size option card component
 * 
 * Displays a single size option with name, price, and selection state.
 * Provides visual feedback for selected/unselected states.
 */
struct SizeOptionCard: View {
    
    // MARK: - Properties
    let variation: MenuItemVariation
    let isSelected: Bool
    let onTap: () -> Void
    
    // MARK: - Design System
    private enum Design {
        static let nameFont: Font = .subheadline
        static let nameWeight: Font.Weight = .semibold
        static let priceFont: Font = .caption
        static let priceWeight: Font.Weight = .medium
        static let spacing: CGFloat = 6
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Design.spacing) {
                // Size name
                Text(variation.name)
                    .font(Design.nameFont)
                    .fontWeight(Design.nameWeight)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Size price
                Text(String(format: "$%.2f", variation.price))
                    .font(Design.priceFont)
                    .fontWeight(Design.priceWeight)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.verticalPadding)
            .background(backgroundColor)
            .cornerRadius(Design.cornerRadius)
            .overlay(borderOverlay)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    /**
     * Background color based on selection state
     */
    private var backgroundColor: Color {
        return isSelected ? Color.accentColor : Color(.systemBackground)
    }
    
    /**
     * Border overlay for visual feedback
     */
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .stroke(
                isSelected ? Color.accentColor : Color(.systemGray4),
                lineWidth: Design.borderWidth
            )
    }
}

// MARK: - Preview

struct SizeSelectionViews_Previews: PreviewProvider {
    static var previews: some View {
        let sampleVariations = [
            MenuItemVariation(id: "small", name: "Small", price: 4.50, ordinal: 1),
            MenuItemVariation(id: "medium", name: "Medium", price: 5.50, ordinal: 2),
            MenuItemVariation(id: "large", name: "Large", price: 6.50, ordinal: 3)
        ]
        
        VStack(spacing: 20) {
            // Size selection with no selection
            SizeSelectionView(
                variations: sampleVariations,
                selectedSizeId: .constant(nil)
            )
            
            // Size selection with medium selected
            SizeSelectionView(
                variations: sampleVariations,
                selectedSizeId: .constant("medium")
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
