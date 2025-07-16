package com.example.siplocalandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
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
                var currentScreen by remember { mutableStateOf("landing") }
                
                when (currentScreen) {
                    "landing" -> LandingScreen(
                        onSignupClick = { currentScreen = "signup" },
                        onLoginClick = { currentScreen = "login" }
                    )
                    "signup" -> SignupScreen(
                        onNavigateBack = { currentScreen = "landing" },
                        onSignupSuccess = { currentScreen = "landing" }
                    )
                    "login" -> LoginScreen(
                        onNavigateBack = { currentScreen = "landing" },
                        onLoginSuccess = { currentScreen = "home" },
                        onForgotPassword = { /* TODO: Implement forgot password */ }
                    )
                    "home" -> HomeScreen(
                        onLogout = { currentScreen = "landing" }
                    )
                }
            }
        }
    }
}