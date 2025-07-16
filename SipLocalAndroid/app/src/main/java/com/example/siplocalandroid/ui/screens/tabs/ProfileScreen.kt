package com.example.siplocalandroid.ui.screens.tabs

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

@Composable
fun ProfileScreen(onSignOut: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Profile Screen")
            Spacer(modifier = Modifier.height(20.dp))
            Button(onClick = onSignOut) {
                Text("Sign Out")
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun ProfileScreenPreview() {
    SipLocalAndroidTheme {
        ProfileScreen(onSignOut = {})
    }
} 