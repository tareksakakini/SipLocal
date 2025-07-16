package com.example.siplocalandroid.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

@Composable
fun EmailVerificationScreen(
    onEmailVerified: () -> Unit = {},
    onSignOut: () -> Unit = {}
) {
    val viewModel: EmailVerificationViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()

    if (uiState.isEmailVerified) {
        LaunchedEffect(Unit) {
            onEmailVerified()
        }
    }

    if (uiState.showDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissDialog() },
            title = { Text(uiState.dialogTitle) },
            text = { Text(uiState.dialogMessage) },
            confirmButton = {
                TextButton(onClick = { viewModel.dismissDialog() }) {
                    Text("OK")
                }
            }
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF2F2F7))
            .padding(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header
            Column(
                verticalArrangement = Arrangement.spacedBy(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    Icons.Default.Email,
                    contentDescription = null,
                    modifier = Modifier.size(80.dp),
                    tint = Color(0xFF654321)
                )

                Text(
                    text = "Verify Your Email",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold
                )

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "We sent a verification link to:",
                        color = Color.Gray
                    )

                    Text(
                        text = uiState.email,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .padding(vertical = 8.dp, horizontal = 16.dp)
                            .background(Color.White, shape = RoundedCornerShape(12.dp))
                            .padding(8.dp)
                    )
                }

                Text(
                    text = "Please check your inbox and click the verification link to continue using the app.",
                    textAlign = TextAlign.Center,
                    color = Color.Gray,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            Spacer(modifier = Modifier.height(30.dp))

            // Action Buttons
            Column(
                verticalArrangement = Arrangement.spacedBy(15.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // "I've Verified" Button
                Button(
                    onClick = { viewModel.checkVerificationStatus() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(55.dp),
                    shape = RoundedCornerShape(28.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF654321)
                    ),
                    enabled = !uiState.isCheckingStatus && !uiState.isResendingEmail
                ) {
                    if (uiState.isCheckingStatus) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                    } else {
                        Icon(Icons.Default.CheckCircle, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("I've Verified My Email")
                    }
                }

                // "Resend Email" Button
                OutlinedButton(
                    onClick = { viewModel.resendVerificationEmail() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(55.dp),
                    shape = RoundedCornerShape(28.dp),
                    enabled = !uiState.isCheckingStatus && !uiState.isResendingEmail,
                    border = BorderStroke(2.dp, Color(0xFF654321))
                ) {
                    if (uiState.isResendingEmail) {
                        CircularProgressIndicator(color = Color(0xFF654321), modifier = Modifier.size(20.dp))
                    } else {
                        Icon(Icons.Default.Refresh, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Resend Verification Email")
                    }
                }
            }
        }

        // Sign Out
        TextButton(
            onClick = onSignOut,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 20.dp)
        ) {
            Text("Sign Out", color = Color.Gray)
        }
    }
}

@Preview(showBackground = true)
@Composable
fun EmailVerificationScreenPreview() {
    SipLocalAndroidTheme {
        EmailVerificationScreen()
    }
} 