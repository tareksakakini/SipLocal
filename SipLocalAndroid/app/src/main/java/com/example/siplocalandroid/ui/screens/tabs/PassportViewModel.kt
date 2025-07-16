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

class PassportViewModel : ViewModel() {
    private val authManager = AuthenticationManager()
    
    private val _uiState = MutableStateFlow<PassportUiState>(PassportUiState.Loading)
    val uiState: StateFlow<PassportUiState> = _uiState
    
    fun loadPassportData(context: Context) {
        viewModelScope.launch {
            _uiState.value = PassportUiState.Loading
            val allShops = DataService.loadCoffeeShops(context)
            val stampedIds = authManager.getStampedShopIds()
            _uiState.value = PassportUiState.Success(
                allShops = allShops,
                stampedShopIds = stampedIds.toSet()
            )
        }
    }
    
    fun toggleStamp(shopId: String) {
        viewModelScope.launch {
            if (_uiState.value is PassportUiState.Success) {
                val currentState = _uiState.value as PassportUiState.Success
                val isCurrentlyStamped = shopId in currentState.stampedShopIds
                
                // Optimistic update
                val newStampedIds = if (isCurrentlyStamped) {
                    currentState.stampedShopIds - shopId
                } else {
                    currentState.stampedShopIds + shopId
                }
                _uiState.value = currentState.copy(stampedShopIds = newStampedIds)
                
                val result = if (isCurrentlyStamped) {
                    authManager.removeStamp(shopId)
                } else {
                    authManager.addStamp(shopId)
                }
                
                if (result.isFailure) {
                    // Revert on failure
                    _uiState.value = currentState
                }
            }
        }
    }
}

sealed class PassportUiState {
    object Loading : PassportUiState()
    data class Success(
        val allShops: List<CoffeeShop>,
        val stampedShopIds: Set<String>
    ) : PassportUiState()
} 