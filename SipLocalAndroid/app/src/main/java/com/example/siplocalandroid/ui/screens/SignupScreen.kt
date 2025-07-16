package com.example.siplocalandroid.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme
import kotlinx.coroutines.delay

enum class UsernameStatus {
    NONE, CHECKING, AVAILABLE, UNAVAILABLE
}

@Composable
fun SignupScreen(
    onNavigateBack: () -> Unit = {},
    onSignupSuccess: () -> Unit = {},
    onNavigateToLogin: () -> Unit = {}
) {
    val viewModel: SignupViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()

    if (uiState.signupSuccess) {
        LaunchedEffect(Unit) {
            onSignupSuccess()
            viewModel.onSignupNavigated()
        }
    }
    
    // Show error dialog
    if (uiState.showErrorDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissErrorDialog() },
            title = { Text("Error") },
            text = { Text(uiState.errorMessage) },
            confirmButton = {
                TextButton(onClick = { viewModel.dismissErrorDialog() }) {
                    Text("OK")
                }
            }
        )
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF2F2F7))
    ) {
        // Back Button
        IconButton(
            onClick = onNavigateBack,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(16.dp)
        ) {
            Icon(
                Icons.Default.ArrowBack,
                contentDescription = "Back",
                tint = Color.Black
            )
        }
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Center
        ) {
            // Card container
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White)
            ) {
                Column {
                    // Accent header
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .background(
                                brush = Brush.horizontalGradient(
                                    colors = listOf(
                                        Color(0xFFE6D9CC),
                                        Color(0xFFB3997F)
                                    )
                                )
                            )
                    )
                    
                    Column(
                        modifier = Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(28.dp)
                    ) {
                        // Header
                        Column(
                            modifier = Modifier.padding(top = 18.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Join SipLocal",
                                fontSize = 28.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.Black
                            )
                            Text(
                                text = "Create your account to discover local flavors",
                                fontSize = 16.sp,
                                color = Color.Gray,
                                textAlign = TextAlign.Center
                            )
                        }
                        
                        // Form
                        Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                            CustomTextField(
                                icon = Icons.Default.Person,
                                placeholder = "Full Name",
                                value = uiState.fullName,
                                onValueChange = viewModel::updateFullName,
                                keyboardType = KeyboardType.Text
                            )
                            
                            CustomTextField(
                                icon = Icons.Default.AccountCircle,
                                placeholder = "Username",
                                value = uiState.username,
                                onValueChange = viewModel::updateUsername,
                                keyboardType = KeyboardType.Text,
                                usernameStatus = uiState.usernameStatus
                            )
                            
                            CustomTextField(
                                icon = Icons.Default.Email,
                                placeholder = "Email",
                                value = uiState.email,
                                onValueChange = viewModel::updateEmail,
                                keyboardType = KeyboardType.Email
                            )
                            
                            CustomPasswordField(
                                icon = Icons.Default.Lock,
                                placeholder = "Password",
                                value = uiState.password,
                                onValueChange = viewModel::updatePassword,
                                isVisible = uiState.isPasswordVisible,
                                onVisibilityChange = viewModel::togglePasswordVisibility
                            )
                            
                            CustomPasswordField(
                                icon = Icons.Default.Lock,
                                placeholder = "Confirm Password",
                                value = uiState.confirmPassword,
                                onValueChange = viewModel::updateConfirmPassword,
                                isVisible = uiState.isConfirmPasswordVisible,
                                onVisibilityChange = viewModel::toggleConfirmPasswordVisibility
                            )
                        }
                        
                        // Sign Up Button
                        Button(
                            onClick = viewModel::signUp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp),
                            shape = RoundedCornerShape(25.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF654321)
                            ),
                            enabled = uiState.isFormValid && !uiState.isLoading
                        ) {
                            if (uiState.isLoading) {
                                CircularProgressIndicator(
                                    color = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            } else {
                                Text(
                                    text = "Sign Up",
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = Color.White
                                )
                            }
                        }
                        
                        // Back to Login
                        TextButton(
                            onClick = onNavigateToLogin,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp)
                        ) {
                            Text(
                                text = "Already have an account? Login",
                                fontSize = 16.sp,
                                color = Color.Blue
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CustomTextField(
    icon: ImageVector,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType = KeyboardType.Text,
    usernameStatus: UsernameStatus = UsernameStatus.NONE
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        trailingIcon = {
            when (usernameStatus) {
                UsernameStatus.CHECKING -> CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp
                )
                UsernameStatus.AVAILABLE -> Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color.Green
                )
                UsernameStatus.UNAVAILABLE -> Icon(
                    Icons.Default.Close,
                    contentDescription = null,
                    tint = Color.Red
                )
                UsernameStatus.NONE -> {}
            }
        },
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        singleLine = true
    )
}

@Composable
fun CustomPasswordField(
    icon: ImageVector,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    isVisible: Boolean,
    onVisibilityChange: () -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        trailingIcon = {
            IconButton(onClick = onVisibilityChange) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = if (isVisible) "Hide password" else "Show password"
                )
            }
        },
        visualTransformation = if (isVisible) VisualTransformation.None else PasswordVisualTransformation(),
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        singleLine = true
    )
}

@Preview(showBackground = true)
@Composable
fun SignupScreenPreview() {
    SipLocalAndroidTheme {
        SignupScreen()
    }
} 