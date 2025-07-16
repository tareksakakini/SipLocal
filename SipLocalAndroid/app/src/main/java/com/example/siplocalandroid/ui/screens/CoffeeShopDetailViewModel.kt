package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CoffeeShopDetailViewModel(private val shopId: String) : ViewModel() {
    private val authManager = AuthenticationManager()
    
    private val _isFavorite = MutableStateFlow(false)
    val isFavorite: StateFlow<Boolean> = _isFavorite
    
    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading
    
    init {
        checkIfFavorite()
    }
    
    private fun checkIfFavorite() {
        viewModelScope.launch {
            _isLoading.value = true
            _isFavorite.value = authManager.isFavorite(shopId)
            _isLoading.value = false
        }
    }
    
    fun toggleFavorite() {
        viewModelScope.launch {
            val currentStatus = _isFavorite.value
            _isFavorite.value = !currentStatus // Optimistic update
            
            val result = if (currentStatus) {
                authManager.removeFavorite(shopId)
            } else {
                authManager.addFavorite(shopId)
            }
            
            if (result.isFailure) {
                _isFavorite.value = currentStatus // Revert on failure
            }
        }
    }
} 