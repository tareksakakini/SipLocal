package com.example.siplocalandroid.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.siplocalandroid.auth.AuthenticationManager
import com.example.siplocalandroid.data.UserData
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SignupUiState(
    val fullName: String = "",
    val username: String = "",
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val isPasswordVisible: Boolean = false,
    val isConfirmPasswordVisible: Boolean = false,
    val usernameStatus: UsernameStatus = UsernameStatus.NONE,
    val isLoading: Boolean = false,
    val signupSuccess: Boolean = false,
    val showErrorDialog: Boolean = false,
    val errorMessage: String = "",
    val isFormValid: Boolean = false
)

class SignupViewModel : ViewModel() {
    private val authManager = AuthenticationManager()
    
    private val _uiState = MutableStateFlow(SignupUiState())
    val uiState: StateFlow<SignupUiState> = _uiState.asStateFlow()
    
    private var usernameCheckJob: Job? = null
    
    fun updateFullName(fullName: String) {
        _uiState.value = _uiState.value.copy(fullName = fullName)
        validateForm()
    }
    
    fun updateUsername(username: String) {
        _uiState.value = _uiState.value.copy(username = username)
        validateForm()
        checkUsernameAvailability(username)
    }
    
    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(email = email)
        validateForm()
    }
    
    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
        validateForm()
    }
    
    fun updateConfirmPassword(confirmPassword: String) {
        _uiState.value = _uiState.value.copy(confirmPassword = confirmPassword)
        validateForm()
    }
    
    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(isPasswordVisible = !_uiState.value.isPasswordVisible)
    }
    
    fun toggleConfirmPasswordVisibility() {
        _uiState.value = _uiState.value.copy(isConfirmPasswordVisible = !_uiState.value.isConfirmPasswordVisible)
    }

    fun onSignupNavigated() {
        _uiState.value = _uiState.value.copy(signupSuccess = false)
    }
    
    fun dismissErrorDialog() {
        _uiState.value = _uiState.value.copy(showErrorDialog = false)
    }
    
    private fun checkUsernameAvailability(username: String) {
        if (username.isEmpty()) {
            _uiState.value = _uiState.value.copy(usernameStatus = UsernameStatus.NONE)
            return
        }
        
        usernameCheckJob?.cancel()
        _uiState.value = _uiState.value.copy(usernameStatus = UsernameStatus.CHECKING)
        
        usernameCheckJob = viewModelScope.launch {
            delay(500) // Debounce
            
            try {
                val isAvailable = authManager.checkUsernameAvailability(username)
                _uiState.value = _uiState.value.copy(
                    usernameStatus = if (isAvailable) UsernameStatus.AVAILABLE else UsernameStatus.UNAVAILABLE
                )
            } catch (e: Exception) {
                // On error, assume available for testing purposes
                _uiState.value = _uiState.value.copy(usernameStatus = UsernameStatus.AVAILABLE)
            }
            validateForm()
        }
    }
    
    private fun validateForm() {
        val state = _uiState.value
        val isValid = state.fullName.isNotEmpty() &&
                state.username.isNotEmpty() &&
                state.email.isNotEmpty() &&
                state.email.contains("@") &&
                state.password.isNotEmpty() &&
                state.password.length >= 6 &&
                state.confirmPassword.isNotEmpty() &&
                state.password == state.confirmPassword &&
                state.usernameStatus == UsernameStatus.AVAILABLE
        
        _uiState.value = _uiState.value.copy(isFormValid = isValid)
    }
    
    fun signUp() {
        if (!_uiState.value.isFormValid) return
        
        _uiState.value = _uiState.value.copy(isLoading = true)
        
        val userData = UserData(
            fullName = _uiState.value.fullName,
            username = _uiState.value.username,
            email = _uiState.value.email
        )
        
        viewModelScope.launch {
            val result = authManager.signUp(
                email = _uiState.value.email,
                password = _uiState.value.password,
                userData = userData
            )
            
            _uiState.value = _uiState.value.copy(isLoading = false)
            
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(signupSuccess = true)
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        showErrorDialog = true,
                        errorMessage = exception.message ?: "An error occurred during sign up"
                    )
                }
            )
        }
    }
} 