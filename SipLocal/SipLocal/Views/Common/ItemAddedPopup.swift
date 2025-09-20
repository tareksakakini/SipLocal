/**
 * ItemAddedPopup.swift
 * SipLocal
 *
 * A standardized, reusable popup component for "Item added" notifications.
 * Ensures complete consistency across all areas of the app.
 *
 * ## Design Specifications
 * - **Background**: Black background for all instances
 * - **Text**: White text with consistent font styling
 * - **Icon**: No checkmark icon for cleaner design
 * - **Animation**: Consistent slide-up animation with opacity
 * - **Positioning**: Bottom-center with proper padding
 *
 * ## Usage
 * ```swift
 * .overlay(
 *     ItemAddedPopup(isVisible: $showItemAddedPopup)
 * )
 * ```
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - ItemAddedPopup Component

/**
 * Reusable popup component for "Item added" notifications
 * 
 * Provides a consistent design across all areas of the app with:
 * - Black background with white text
 * - No checkmark icon for cleaner appearance
 * - Consistent animations and positioning
 * - Full accessibility support
 */
struct ItemAddedPopup: View {
    // MARK: - Properties
    @Binding var isVisible: Bool
    
    // MARK: - Design Constants
    private enum Design {
        // Layout (matching MenuCategorySelectionView popup constants exactly)
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 16
        static let bottomPadding: CGFloat = 40
        static let sidePadding: CGFloat = 0  // No side padding needed with Spacers
        
        // Animation
        static let animationDuration: Double = 0.3
        static let autoDismissDelay: Double = 2.0
        
        // Styling
        static let backgroundColor = Color.black.opacity(0.85)  // Matches MenuCategorySelectionView exactly
        static let textColor = Color.white
        static let shadowRadius: CGFloat = 8  // Matches MenuCategorySelectionView
        static let shadowOpacity: Double = 1.0  // Full shadow opacity since background is already semi-transparent
        
        // Typography
        static let fontSize: CGFloat = 16
        static let fontWeight: Font.Weight = .medium
    }
    
    // MARK: - Body
    var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("Item added")
                            .font(.system(size: Design.fontSize, weight: Design.fontWeight))
                            .foregroundColor(Design.textColor)
                    }
                    .padding(.horizontal, Design.horizontalPadding)
                    .padding(.vertical, Design.verticalPadding)
                    .background(Design.backgroundColor)
                    .cornerRadius(Design.cornerRadius)
                    .shadow(
                        radius: Design.shadowRadius
                    )
                    
                    Spacer()
                }
                .padding(.bottom, Design.bottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: Design.animationDuration), value: isVisible)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item successfully added to cart")
        .accessibilityAddTraits(.playsSound)
    }
}

// MARK: - Convenience Methods

extension ItemAddedPopup {
    /**
     * Show the popup with automatic dismissal
     * 
     * This method handles the complete show/hide cycle:
     * 1. Shows the popup with animation
     * 2. Automatically hides it after the specified delay
     * 
     * ## Usage
     * ```swift
     * ItemAddedPopup.show(isVisible: $showPopup)
     * ```
     */
    static func show(isVisible: Binding<Bool>) {
        // Show popup
        withAnimation(.easeInOut(duration: Design.animationDuration)) {
            isVisible.wrappedValue = true
        }
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.autoDismissDelay) {
            withAnimation(.easeInOut(duration: Design.animationDuration)) {
                isVisible.wrappedValue = false
            }
        }
    }
}

// MARK: - Preview

struct ItemAddedPopup_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Visible state
            ItemAddedPopup(isVisible: .constant(true))
                .previewDisplayName("Visible")
                .background(Color.gray.opacity(0.3))
            
            // Hidden state
            ItemAddedPopup(isVisible: .constant(false))
                .previewDisplayName("Hidden")
                .background(Color.gray.opacity(0.3))
            
            // Dark mode
            ItemAddedPopup(isVisible: .constant(true))
                .previewDisplayName("Dark Mode")
                .preferredColorScheme(.dark)
                .background(Color.gray.opacity(0.3))
        }
    }
}
