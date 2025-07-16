package com.example.siplocalandroid.data

import kotlinx.serialization.Serializable
import com.google.android.gms.maps.model.LatLng

@Serializable
data class MenuItemModifier(
    val id: String,
    val name: String,
    val price: Double,
    val isDefault: Boolean
)

@Serializable
data class MenuItemModifierList(
    val id: String,
    val name: String,
    val selectionType: String, // "SINGLE" or "MULTIPLE"
    val minSelections: Int,
    val maxSelections: Int,
    val modifiers: List<MenuItemModifier>
)

@Serializable
data class MenuItem(
    val name: String,
    val price: Double,
    val customizations: List<String>? = null,
    val imageURL: String? = null,
    val modifierLists: List<MenuItemModifierList>? = null
) {
    val id: String get() = name
}

@Serializable
data class MenuCategory(
    val name: String,
    val items: List<MenuItem>
) {
    val id: String get() = name
}

@Serializable
data class SquareCredentials(
    val appID: String,
    val accessToken: String,
    val locationId: String
)

@Serializable
data class CoffeeShop(
    val id: String,
    val name: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    val phone: String,
    val website: String,
    val description: String,
    val imageName: String,
    val stampName: String,
    val menu: SquareCredentials
) {
    val coordinate: LatLng get() = LatLng(latitude, longitude)
} 