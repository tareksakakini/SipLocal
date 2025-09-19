//
//  PassportView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Design Constants

private enum Design {
    // Grid Layout
    static let gridColumns: Int = 3
    static let gridSpacing: CGFloat = 16
    
    // Progress Section
    static let progressSectionPadding: CGFloat = 16
    static let progressTintColor = Color.blue
    
    // Stamps
    static let stampAnimationDuration: Double = 0.2
    static let unstampedOpacity: Double = 0.6
    static let stampedOpacity: Double = 1.0
    static let unstampedGrayscale: Double = 1.0
    static let stampedGrayscale: Double = 0.0
    
    // Layout
    static let sectionSpacing: CGFloat = 0
}

// MARK: - Passport View

/// Loyalty stamps collection view showing user's progress across coffee shops
/// Users can tap stamps to toggle their collection status (for testing/demo purposes)
struct PassportView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    private let coffeeShops = DataService.loadCoffeeShops()
    
    // Grid layout configuration
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Design.gridSpacing), count: Design.gridColumns)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Design.sectionSpacing) {
                progressSection
                stampsGrid
            }
            .navigationTitle("Passport")
        }
    }
    
    // MARK: - View Components
    
    /// Progress section showing collection status
    private var progressSection: some View {
        VStack(spacing: 8) {
            progressHeader
            progressBar
        }
        .padding(Design.progressSectionPadding)
    }
    
    /// Progress header with title and count
    private var progressHeader: some View {
        HStack {
            Text("Stamps Collected")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            Text("\(authManager.stampedShops.count) of \(coffeeShops.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("\(authManager.stampedShops.count) stamps collected out of \(coffeeShops.count) total")
        }
    }
    
    /// Progress bar showing collection completion
    private var progressBar: some View {
        ProgressView(
            value: Double(authManager.stampedShops.count),
            total: Double(coffeeShops.count)
        )
        .progressViewStyle(LinearProgressViewStyle(tint: Design.progressTintColor))
        .animation(.easeInOut, value: authManager.stampedShops.count)
        .accessibilityLabel("Collection progress: \(Int((Double(authManager.stampedShops.count) / Double(coffeeShops.count)) * 100))% complete")
    }
    
    /// Scrollable grid of loyalty stamps
    private var stampsGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Design.gridSpacing) {
                ForEach(coffeeShops) { shop in
                    stampView(for: shop)
                }
            }
            .padding(Design.gridSpacing)
        }
    }
    
    /// Individual stamp view with tap interaction
    private func stampView(for shop: CoffeeShop) -> some View {
        let isStamped = authManager.stampedShops.contains(shop.id)
        
        return Image(shop.stampName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(minWidth: 0, maxWidth: .infinity)
            .grayscale(isStamped ? Design.stampedGrayscale : Design.unstampedGrayscale)
            .opacity(isStamped ? Design.stampedOpacity : Design.unstampedOpacity)
            .onTapGesture {
                toggleStamp(for: shop, isCurrentlyStamped: isStamped)
            }
            .accessibilityLabel("Stamp for \(shop.name)")
            .accessibilityValue(isStamped ? "Collected" : "Not collected")
            .accessibilityHint("Tap to \(isStamped ? "remove" : "add") stamp")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Actions
    
    /// Toggle stamp collection status for a coffee shop
    private func toggleStamp(for shop: CoffeeShop, isCurrentlyStamped: Bool) {
        withAnimation(.easeInOut(duration: Design.stampAnimationDuration)) {
            if isCurrentlyStamped {
                authManager.removeStamp(shopId: shop.id) { _ in }
            } else {
                authManager.addStamp(shopId: shop.id) { _ in }
            }
        }
    }
}

// MARK: - Previews

struct PassportView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with some stamps collected
            PassportView()
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.stampedShops = ["1", "3", "5"] // Mock some collected stamps
                    return authManager
                }())
                .previewDisplayName("With Stamps")
            
            // Preview with no stamps
            PassportView()
                .environmentObject(AuthenticationManager())
                .previewDisplayName("Empty Collection")
        }
    }
} 