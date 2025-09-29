/**
 * ModifierComponents.swift
 * SipLocal
 *
 * Components for handling menu item modifiers and customizations.
 * Extracted from MenuItemsView.swift for better organization.
 *
 * ## Features
 * - **ModifierListSection**: Main container for modifier groups
 * - **MultipleSelectionRow**: Checkbox-style selection for multiple modifiers
 * - **SegmentedModifierPicker**: Segmented control for 3 or fewer options
 * - **DefaultModifierPicker**: Wheel picker for more than 3 options
 * - **Smart UI Selection**: Automatically chooses best UI based on option count
 *
 * ## Architecture
 * - **Single Responsibility**: Each component handles one modifier interaction type
 * - **Reusable Components**: Can be used in any customization context
 * - **Smart Selection**: Automatic UI selection based on modifier count and type
 * - **Validation**: Built-in min/max selection validation
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - ModifierListSection

/**
 * Main container for modifier groups
 * 
 * Displays a modifier list with appropriate UI based on selection type
 * and number of options. Handles single and multiple selection modes.
 */
struct ModifierListSection: View {
    
    // MARK: - Properties
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    // MARK: - Design System
    private enum Design {
        static let titleFont: Font = .title3
        static let titleWeight: Font.Weight = .semibold
        static let requirementFont: Font = .caption
        static let sectionSpacing: CGFloat = 8
        static let headerSpacing: CGFloat = 4
        static let padding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let maxSegmentedOptions: Int = 3
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.sectionSpacing) {
            // Header with title and requirements
            modifierHeader
            
            // Modifier selection UI
            modifierSelectionUI
        }
        .padding(Design.padding)
        .background(Color.white)
        .cornerRadius(Design.cornerRadius)
    }
    
    // MARK: - View Components
    
    /**
     * Header section with title and selection requirements
     */
    private var modifierHeader: some View {
        VStack(alignment: .leading, spacing: Design.headerSpacing) {
            Text(modifierList.name)
                .font(Design.titleFont)
                .fontWeight(Design.titleWeight)
            
            // Show selection requirements
            if shouldShowRequirements {
                requirementText
            }
        }
    }
    
    /**
     * Requirement text based on min/max selections
     */
    @ViewBuilder
    private var requirementText: some View {
        let requirementText = buildRequirementText()
        if !requirementText.isEmpty {
            Text(requirementText)
                .font(Design.requirementFont)
                .foregroundColor(.secondary)
        }
    }
    
    /**
     * Main modifier selection UI
     */
    @ViewBuilder
    private var modifierSelectionUI: some View {
        if isSingleSelection {
            singleSelectionUI
        } else {
            multipleSelectionUI
        }
    }
    
    /**
     * Single selection UI (segmented or wheel picker)
     */
    @ViewBuilder
    private var singleSelectionUI: some View {
        if modifierList.modifiers.count <= Design.maxSegmentedOptions {
            // Segmented picker for 3 or fewer options
            SegmentedModifierPicker(
                modifierList: modifierList,
                selectedModifiers: $selectedModifiers
            )
        } else {
            // Default picker for more than 3 options
            DefaultModifierPicker(
                modifierList: modifierList,
                selectedModifiers: $selectedModifiers
            )
        }
    }
    
    /**
     * Multiple selection UI (checkbox list)
     */
    private var multipleSelectionUI: some View {
        VStack(alignment: .leading, spacing: Design.sectionSpacing) {
            ForEach(modifierList.modifiers) { modifier in
                MultipleSelectionRow(
                    modifier: modifier,
                    isSelected: selectedModifiers.contains(modifier.id),
                    onToggle: {
                        handleModifierToggle(modifier)
                    }
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /**
     * Check if this is a single selection modifier list
     */
    private var isSingleSelection: Bool {
        return modifierList.selectionType == "SINGLE" || modifierList.maxSelections == 1
    }
    
    /**
     * Check if requirements should be shown
     */
    private var shouldShowRequirements: Bool {
        return modifierList.minSelections > 0 || modifierList.maxSelections != 1
    }
    
    // MARK: - Helper Methods
    
    /**
     * Handle modifier toggle for multiple selection
     */
    private func handleModifierToggle(_ modifier: MenuItemModifier) {
        if selectedModifiers.contains(modifier.id) {
            // Don't allow deselection if at minimum
            if selectedModifiers.count > modifierList.minSelections {
                selectedModifiers.remove(modifier.id)
            }
        } else {
            // Don't allow selection if at maximum (handle -1 as unlimited)
            if modifierList.maxSelections == -1 || selectedModifiers.count < modifierList.maxSelections {
                selectedModifiers.insert(modifier.id)
            }
        }
    }
    
    /**
     * Build requirement text based on min/max selections
     */
    private func buildRequirementText() -> String {
        if modifierList.minSelections > 0 && modifierList.maxSelections > 1 {
            if modifierList.maxSelections == -1 {
                return "Select at least \(modifierList.minSelections)"
            } else if modifierList.minSelections == modifierList.maxSelections {
                return "Select \(modifierList.minSelections)"
            } else {
                return "Select \(modifierList.minSelections)-\(modifierList.maxSelections)"
            }
        } else if modifierList.minSelections > 0 {
            return "Select at least \(modifierList.minSelections)"
        } else if modifierList.maxSelections > 1 {
            return "Select up to \(modifierList.maxSelections)"
        }
        return ""
    }
}

// MARK: - MultipleSelectionRow

/**
 * Checkbox-style row for multiple selection modifiers
 * 
 * Displays a modifier option with checkbox, name, and price.
 * Handles selection state and validation.
 */
struct MultipleSelectionRow: View {
    
    // MARK: - Properties
    let modifier: MenuItemModifier
    let isSelected: Bool
    let onToggle: () -> Void
    
    // MARK: - Design System
    private enum Design {
        static let checkboxSize: CGFloat = 20
        static let nameFont: Font = .body
        static let priceFont: Font = .body
        static let verticalPadding: CGFloat = 4
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Checkbox
                checkboxIcon
                
                // Modifier name
                Text(modifier.name)
                    .font(Design.nameFont)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Price (if applicable)
                priceText
            }
            .padding(.vertical, Design.verticalPadding)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - View Components
    
    /**
     * Checkbox icon with selection state
     */
    private var checkboxIcon: some View {
        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
            .foregroundColor(isSelected ? .blue : .gray)
            .font(.system(size: Design.checkboxSize))
    }
    
    /**
     * Price text (if modifier has additional cost)
     */
    @ViewBuilder
    private var priceText: some View {
        if modifier.price > 0 {
            Text("+$\(modifier.price, specifier: "%.2f")")
                .font(Design.priceFont)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - SegmentedModifierPicker

/**
 * Segmented control picker for 3 or fewer modifier options
 * 
 * Provides a clean segmented control interface with price display
 * for modifier options with few choices.
 */
struct SegmentedModifierPicker: View {
    
    // MARK: - Properties
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    // MARK: - Design System
    private enum Design {
        static let spacing: CGFloat = 8
        static let priceFont: Font = .caption
        static let topPadding: CGFloat = 4
    }
    
    // MARK: - Computed Properties
    
    /**
     * Currently selected modifier ID
     */
    private var selectedModifierId: String {
        selectedModifiers.first ?? ""
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacing) {
            // Segmented picker
            segmentedControl
            
            // Price information
            priceInformation
        }
    }
    
    // MARK: - View Components
    
    /**
     * Segmented control for modifier selection
     */
    private var segmentedControl: some View {
        Picker(modifierList.name, selection: Binding(
            get: { selectedModifierId },
            set: { newValue in
                selectedModifiers.removeAll()
                if !newValue.isEmpty {
                    selectedModifiers.insert(newValue)
                }
            }
        )) {
            ForEach(modifierList.modifiers) { modifier in
                Text(modifier.name)
                    .tag(modifier.id)
            }
        }
        .pickerStyle(.segmented)
    }
    
    /**
     * Price information for selected modifier
     */
    @ViewBuilder
    private var priceInformation: some View {
        if let selectedId = selectedModifiers.first,
           let selectedModifier = modifierList.modifiers.first(where: { $0.id == selectedId }) {
            HStack {
                Spacer()
                priceText(for: selectedModifier)
            }
            .padding(.top, Design.topPadding)
        }
    }
    
    /**
     * Price text for a modifier
     */
    @ViewBuilder
    private func priceText(for modifier: MenuItemModifier) -> some View {
        if modifier.price > 0 {
            Text("+$\(modifier.price, specifier: "%.2f")")
                .font(Design.priceFont)
                .foregroundColor(.secondary)
        } else {
            Text("No extra charge")
                .font(Design.priceFont)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - DefaultModifierPicker

/**
 * Wheel picker for more than 3 modifier options
 * 
 * Provides a wheel picker interface for modifier options with
 * many choices, showing both name and price in the picker.
 */
struct DefaultModifierPicker: View {
    
    // MARK: - Properties
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    // MARK: - Design System
    private enum Design {
        static let spacing: CGFloat = 0
        static let verticalPadding: CGFloat = 4
        static let pickerHeight: CGFloat = 100
    }
    
    // MARK: - Computed Properties
    
    /**
     * Currently selected modifier ID
     */
    private var selectedModifierId: String {
        selectedModifiers.first ?? ""
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacing) {
            Picker(modifierList.name, selection: Binding(
                get: { selectedModifierId },
                set: { newValue in
                    selectedModifiers.removeAll()
                    if !newValue.isEmpty {
                        selectedModifiers.insert(newValue)
                    }
                }
            )) {
                ForEach(modifierList.modifiers) { modifier in
                    modifierPickerRow(for: modifier)
                        .tag(modifier.id)
                }
            }
            .pickerStyle(.wheel)
            .padding(.vertical, Design.verticalPadding)
            .frame(height: Design.pickerHeight)
        }
    }
    
    // MARK: - View Components
    
    /**
     * Individual row in the wheel picker
     */
    private func modifierPickerRow(for modifier: MenuItemModifier) -> some View {
        HStack {
            Text(modifier.name)
            Spacer()
            if modifier.price > 0 {
                Text("+$\(modifier.price, specifier: "%.2f")")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

struct ModifierComponents_Previews: PreviewProvider {
    static var previews: some View {
        let sizeModifierList = MenuItemModifierList(
            id: "size_list",
            name: "Size",
            selectionType: "SINGLE",
            minSelections: 1,
            maxSelections: 1,
            modifiers: [
                MenuItemModifier(id: "small", name: "Small", price: 0.0, isDefault: false),
                MenuItemModifier(id: "medium", name: "Medium", price: 0.50, isDefault: true),
                MenuItemModifier(id: "large", name: "Large", price: 1.00, isDefault: false)
            ]
        )
        
        let milkModifierList = MenuItemModifierList(
            id: "milk_list",
            name: "Milk Options",
            selectionType: "SINGLE",
            minSelections: 1,
            maxSelections: 1,
            modifiers: [
                MenuItemModifier(id: "whole", name: "Whole Milk", price: 0.0, isDefault: true),
                MenuItemModifier(id: "skim", name: "Skim Milk", price: 0.0, isDefault: false),
                MenuItemModifier(id: "almond", name: "Almond Milk", price: 0.65, isDefault: false),
                MenuItemModifier(id: "oat", name: "Oat Milk", price: 0.65, isDefault: false),
                MenuItemModifier(id: "soy", name: "Soy Milk", price: 0.60, isDefault: false),
                MenuItemModifier(id: "coconut", name: "Coconut Milk", price: 0.70, isDefault: false)
            ]
        )
        
        let addonsModifierList = MenuItemModifierList(
            id: "addons_list",
            name: "Add-ons",
            selectionType: "MULTIPLE",
            minSelections: 0,
            maxSelections: 3,
            modifiers: [
                MenuItemModifier(id: "extra_shot", name: "Extra Shot", price: 0.75, isDefault: false),
                MenuItemModifier(id: "decaf", name: "Make it Decaf", price: 0.0, isDefault: false),
                MenuItemModifier(id: "whipped_cream", name: "Whipped Cream", price: 0.50, isDefault: false),
                MenuItemModifier(id: "vanilla_syrup", name: "Vanilla Syrup", price: 0.60, isDefault: false),
                MenuItemModifier(id: "caramel_syrup", name: "Caramel Syrup", price: 0.60, isDefault: false)
            ]
        )
        
        ScrollView {
            VStack(spacing: 20) {
                // Segmented picker (3 options)
                ModifierListSection(
                    modifierList: sizeModifierList,
                    selectedModifiers: .constant(["medium"])
                )
                
                // Wheel picker (6 options)
                ModifierListSection(
                    modifierList: milkModifierList,
                    selectedModifiers: .constant(["whole"])
                )
                
                // Multiple selection (checkboxes)
                ModifierListSection(
                    modifierList: addonsModifierList,
                    selectedModifiers: .constant(["extra_shot", "whipped_cream"])
                )
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}
