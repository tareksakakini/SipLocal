package com.example.siplocalandroid.ui.screens.tabs

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

@Composable
fun OrderScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Text("Order Screen")
    }
}

@Preview(showBackground = true)
@Composable
fun OrderScreenPreview() {
    SipLocalAndroidTheme {
        OrderScreen()
    }
} 