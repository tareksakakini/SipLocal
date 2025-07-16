package com.example.siplocalandroid.ui.screens.tabs

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.siplocalandroid.R
import com.example.siplocalandroid.data.CoffeeShop
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme

// Helper function to get drawable resource ID for stamps
fun getStampResourceId(stampName: String): Int {
    return when (stampName) {
        "qisa_stamp" -> R.drawable.qisa_stamp
        "qamaria_stamp" -> R.drawable.qamaria_stamp
        "sanaa_stamp" -> R.drawable.sanaa_stamp
        "estelle_stamp" -> R.drawable.estelle_stamp
        "themill_stamp" -> R.drawable.themill_stamp
        else -> R.drawable.qisa_stamp // Default fallback
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PassportScreen() {
    val viewModel: PassportViewModel = viewModel()
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    
    LaunchedEffect(key1 = true) {
        viewModel.loadPassportData(context)
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Passport", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold) }
            )
        }
    ) { paddingValues ->
        when (val state = uiState) {
            is PassportUiState.Loading -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            is PassportUiState.Success -> {
                Column(modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)) {
                    PassportProgress(
                        stampedCount = state.stampedShopIds.size,
                        totalCount = state.allShops.size
                    )
                    StampGrid(
                        shops = state.allShops,
                        stampedIds = state.stampedShopIds,
                        onStampClick = { viewModel.toggleStamp(it) }
                    )
                }
            }
        }
    }
}

@Composable
fun PassportProgress(stampedCount: Int, totalCount: Int) {
    val animatedProgress by animateFloatAsState(
        targetValue = if (totalCount > 0) stampedCount.toFloat() / totalCount.toFloat() else 0f,
        animationSpec = tween(durationMillis = 1000)
    )
    
    Column(modifier = Modifier
        .fillMaxWidth()
        .padding(16.dp)) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Text("Stamps Collected", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.weight(1f))
            Text("$stampedCount of $totalCount", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
        }
        Spacer(modifier = Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = animatedProgress,
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
        )
    }
}

@Composable
fun StampGrid(
    shops: List<CoffeeShop>,
    stampedIds: Set<String>,
    onStampClick: (String) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(shops) { shop ->
            val isStamped = shop.id in stampedIds
            StampItem(
                stampName = shop.stampName,
                isStamped = isStamped,
                onClick = { onStampClick(shop.id) }
            )
        }
    }
}

@Composable
fun StampItem(stampName: String, isStamped: Boolean, onClick: () -> Unit) {
    val animatedAlpha by animateFloatAsState(
        targetValue = if (isStamped) 1.0f else 0.6f,
        animationSpec = tween(durationMillis = 300)
    )
    
    Image(
        painter = painterResource(id = getStampResourceId(stampName)),
        contentDescription = stampName,
        modifier = Modifier
            .aspectRatio(1f)
            .alpha(animatedAlpha)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null, // This removes the ripple effect
                onClick = onClick
            ),
        contentScale = ContentScale.Fit,
        colorFilter = if (isStamped) null else ColorFilter.tint(Color.Gray)
    )
}

@Preview(showBackground = true)
@Composable
fun PassportScreenPreview() {
    SipLocalAndroidTheme {
        PassportScreen()
    }
} 