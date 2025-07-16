package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

class CoffeeShopDetailViewModelFactory(private val shopId: String) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(CoffeeShopDetailViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return CoffeeShopDetailViewModel(shopId) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
} 