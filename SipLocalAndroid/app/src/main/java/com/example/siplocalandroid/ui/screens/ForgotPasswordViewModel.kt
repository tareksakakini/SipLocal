package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ForgotPasswordUiState(
    val email: String = "",
    val isLoading: Boolean = false,
    val showDialog: Boolean = false,
    val dialogTitle: String = "",
    val dialogMessage: String = "",
    val isSuccess: Boolean = false,
    val isFormValid: Boolean = false
)

class ForgotPasswordViewModel : ViewModel() {
    private val authManager = AuthenticationManager()

    private val _uiState = MutableStateFlow(ForgotPasswordUiState())
    val uiState: StateFlow<ForgotPasswordUiState> = _uiState.asStateFlow()

    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(email = email)
        validateForm()
    }

    fun dismissDialog() {
        _uiState.value = _uiState.value.copy(showDialog = false)
    }

    private fun validateForm() {
        val state = _uiState.value
        val isValid = state.email.isNotEmpty() && state.email.contains("@")
        _uiState.value = _uiState.value.copy(isFormValid = isValid)
    }

    fun sendResetLink() {
        if (!_uiState.value.isFormValid) return

        _uiState.value = _uiState.value.copy(isLoading = true)

        viewModelScope.launch {
            val result = authManager.sendPasswordReset(email = _uiState.value.email)

            _uiState.value = _uiState.value.copy(isLoading = false)

            result.fold(
                onSuccess = { message ->
                    _uiState.value = _uiState.value.copy(
                        showDialog = true,
                        dialogTitle = "Success",
                        dialogMessage = message,
                        isSuccess = true
                    )
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        showDialog = true,
                        dialogTitle = "Error",
                        dialogMessage = exception.message ?: "An unknown error occurred.",
                        isSuccess = false
                    )
                }
            )
        }
    }
} 