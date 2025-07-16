package com.example.siplocalandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.example.siplocalandroid.auth.AuthenticationManager
import com.example.siplocalandroid.ui.screens.EmailVerificationScreen
import com.example.siplocalandroid.ui.screens.ForgotPasswordScreen
import com.example.siplocalandroid.ui.screens.HomeScreen
import com.example.siplocalandroid.ui.screens.LandingScreen
import com.example.siplocalandroid.ui.screens.LoginScreen
import com.example.siplocalandroid.ui.screens.SignupScreen
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SipLocalAndroidTheme {
                var currentScreen by remember { mutableStateOf(getInitialScreen()) }

                when (currentScreen) {
                    "landing" -> LandingScreen(
                        onSignupClick = { currentScreen = "signup" },
                        onLoginClick = { currentScreen = "login" }
                    )
                    "signup" -> SignupScreen(
                        onNavigateBack = { currentScreen = "landing" },
                        onSignupSuccess = { currentScreen = "email_verification" },
                        onNavigateToLogin = { currentScreen = "login" }
                    )
                    "login" -> LoginScreen(
                        onNavigateBack = { currentScreen = "landing" },
                        onLoginSuccess = {
                            currentScreen = if (AuthenticationManager().currentUser?.isEmailVerified == true) {
                                "home"
                            } else {
                                "email_verification"
                            }
                         },
                        onForgotPassword = { currentScreen = "forgot_password" }
                    )
                    "home" -> HomeScreen(
                        onLogout = {
                            AuthenticationManager().signOut()
                            currentScreen = "landing"
                        }
                    )
                    "forgot_password" -> ForgotPasswordScreen(
                        onNavigateBack = { currentScreen = "login" },
                        onSuccess = { currentScreen = "login" }
                    )
                    "email_verification" -> EmailVerificationScreen(
                        onEmailVerified = { currentScreen = "home" },
                        onSignOut = {
                            AuthenticationManager().signOut()
                            currentScreen = "landing"
                        }
                    )
                }
            }
        }
    }

    private fun getInitialScreen(): String {
        val authManager = AuthenticationManager()
        return when {
            authManager.isAuthenticated && authManager.currentUser?.isEmailVerified == true -> "home"
            authManager.isAuthenticated && authManager.currentUser?.isEmailVerified == false -> "email_verification"
            else -> "landing"
        }
    }
}