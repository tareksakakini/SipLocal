package com.example.siplocalandroid.ui.screens

import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.example.siplocalandroid.R
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

@Composable
fun LandingScreen() {
    val context = LocalContext.current
    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            val videoUri = Uri.parse("android.resource://${context.packageName}/${R.raw.signup_video}")
            val mediaItem = MediaItem.fromUri(videoUri)
            setMediaItem(mediaItem)
            prepare()
            playWhenReady = true
            repeatMode = ExoPlayer.REPEAT_MODE_ONE
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        DisposableEffect(Unit) {
            onDispose {
                exoPlayer.release()
            }
        }

        AndroidView(
            factory = {
                PlayerView(it).apply {
                    player = exoPlayer
                    useController = false
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        Surface(
            color = Color.Black.copy(alpha = 0.4f),
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 40.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "SipLocal",
                    style = TextStyle(
                        fontSize = 64.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    ),
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.weight(1f))
                Button(
                    onClick = { /* TODO: Navigate to Login */ },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(55.dp),
                    shape = RoundedCornerShape(27.5.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.2f),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = "Login",
                        style = TextStyle(
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                Spacer(modifier = Modifier.height(20.dp))
                Button(
                    onClick = { /* TODO: Navigate to Signup */ },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(55.dp),
                    shape = RoundedCornerShape(27.5.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = Color.Blue
                    )
                ) {
                    Text(
                        text = "Sign Up",
                        style = TextStyle(
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
                }
                Spacer(modifier = Modifier.height(30.dp))
                Text(
                    text = "Discover local flavors",
                    style = TextStyle(
                        fontSize = 16.sp,
                        color = Color.White.copy(alpha = 0.8f)
                    ),
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(30.dp))
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun LandingScreenPreview() {
    SipLocalAndroidTheme {
        LandingScreen()
    }
} 