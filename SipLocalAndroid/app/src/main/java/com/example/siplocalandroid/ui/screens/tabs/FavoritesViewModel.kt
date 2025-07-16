package com.example.siplocalandroid.ui.screens.tabs

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import com.example.siplocalandroid.data.CoffeeShop
import com.example.siplocalandroid.data.DataService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class FavoritesViewModel : ViewModel() {
    private val authManager = AuthenticationManager()
    
    private val _uiState = MutableStateFlow<FavoritesUiState>(FavoritesUiState.Loading)
    val uiState: StateFlow<FavoritesUiState> = _uiState
    
    fun fetchFavoriteShops(context: Context) {
        viewModelScope.launch {
            _uiState.value = FavoritesUiState.Loading
            val favoriteIds = authManager.getFavoriteShopIds()
            if (favoriteIds.isEmpty()) {
                _uiState.value = FavoritesUiState.Empty
            } else {
                val allShops = DataService.loadCoffeeShops(context)
                val favoriteShops = allShops.filter { it.id in favoriteIds }
                _uiState.value = FavoritesUiState.Success(favoriteShops)
            }
        }
    }
}

sealed class FavoritesUiState {
    object Loading : FavoritesUiState()
    object Empty : FavoritesUiState()
    data class Success(val coffeeShops: List<CoffeeShop>) : FavoritesUiState()
} 