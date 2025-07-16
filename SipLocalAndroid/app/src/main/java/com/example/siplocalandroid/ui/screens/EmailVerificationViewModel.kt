package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class EmailVerificationUiState(
    val email: String = "",
    val isEmailVerified: Boolean = false,
    val isCheckingStatus: Boolean = false,
    val isResendingEmail: Boolean = false,
    val showDialog: Boolean = false,
    val dialogTitle: String = "",
    val dialogMessage: String = ""
)

class EmailVerificationViewModel : ViewModel() {
    private val authManager = AuthenticationManager()

    private val _uiState = MutableStateFlow(EmailVerificationUiState())
    val uiState: StateFlow<EmailVerificationUiState> = _uiState.asStateFlow()

    init {
        _uiState.value = _uiState.value.copy(
            email = authManager.currentUser?.email ?: "",
            isEmailVerified = authManager.currentUser?.isEmailVerified ?: false
        )
    }

    fun dismissDialog() {
        _uiState.value = _uiState.value.copy(showDialog = false)
    }

    fun checkVerificationStatus() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isCheckingStatus = true)
            val isVerified = authManager.reloadUser()
            _uiState.value = _uiState.value.copy(
                isCheckingStatus = false,
                isEmailVerified = isVerified
            )
            if (!isVerified) {
                _uiState.value = _uiState.value.copy(
                    showDialog = true,
                    dialogTitle = "Not Verified Yet",
                    dialogMessage = "Your email has not been verified yet. Please check your inbox or resend the email."
                )
            }
        }
    }

    fun resendVerificationEmail() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isResendingEmail = true)
            val result = authManager.sendVerificationEmail()
            _uiState.value = _uiState.value.copy(isResendingEmail = false)
            result.fold(
                onSuccess = { message ->
                    _uiState.value = _uiState.value.copy(
                        showDialog = true,
                        dialogTitle = "Email Sent",
                        dialogMessage = message
                    )
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        showDialog = true,
                        dialogTitle = "Error",
                        dialogMessage = exception.message ?: "An unknown error occurred."
                    )
                }
            )
        }
    }
} 