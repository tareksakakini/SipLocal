package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class LoginUiState(
    val email: String = "",
    val password: String = "",
    val isPasswordVisible: Boolean = false,
    val isLoading: Boolean = false,
    val showSuccessDialog: Boolean = false,
    val showErrorDialog: Boolean = false,
    val errorMessage: String = "",
    val isFormValid: Boolean = false
)

class LoginViewModel : ViewModel() {
    private val authManager = AuthenticationManager()
    
    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()
    
    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(email = email)
        validateForm()
    }
    
    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
        validateForm()
    }
    
    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(isPasswordVisible = !_uiState.value.isPasswordVisible)
    }
    
    fun dismissErrorDialog() {
        _uiState.value = _uiState.value.copy(showErrorDialog = false)
    }
    
    private fun validateForm() {
        val state = _uiState.value
        val isValid = state.email.isNotEmpty() &&
                state.email.contains("@") &&
                state.password.isNotEmpty()
        
        _uiState.value = _uiState.value.copy(isFormValid = isValid)
    }
    
    fun login() {
        if (!_uiState.value.isFormValid) return
        
        _uiState.value = _uiState.value.copy(isLoading = true)
        
        viewModelScope.launch {
            val result = authManager.signIn(
                email = _uiState.value.email,
                password = _uiState.value.password
            )
            
            _uiState.value = _uiState.value.copy(isLoading = false)
            
            result.fold(
                onSuccess = { _ ->
                    _uiState.value = _uiState.value.copy(showSuccessDialog = true)
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        showErrorDialog = true,
                        errorMessage = exception.message ?: "An unknown error occurred."
                    )
                }
            )
        }
    }
} 