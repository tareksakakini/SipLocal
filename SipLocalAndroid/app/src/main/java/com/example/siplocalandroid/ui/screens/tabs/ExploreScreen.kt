package com.example.siplocalandroid.ui.screens.tabs

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import com.example.siplocalandroid.data.CoffeeShop
import com.example.siplocalandroid.data.DataService
import androidx.compose.ui.draw.scale

@Composable
fun ExploreScreen() {
    val context = LocalContext.current
    val coffeeShops = remember { 
        try {
            DataService.loadCoffeeShops(context)
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
    var searchText by remember { mutableStateOf("") }
    var selectedShop by remember { mutableStateOf<CoffeeShop?>(null) }
    var cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(38.5816, -121.4944), // Sacramento coordinates
            11f
        )
    }
    
    // Search results
    val searchResults = remember(searchText) {
        if (searchText.isEmpty()) {
            emptyList()
        } else {
            coffeeShops.filter { shop ->
                shop.name.contains(searchText, ignoreCase = true)
            }.take(3)
        }
    }

    // Animate camera when a shop is selected
    LaunchedEffect(selectedShop) {
        selectedShop?.let { shop ->
            cameraPositionState.animate(
                update = CameraUpdateFactory.newLatLngZoom(
                    shop.coordinate,
                    15f
                ),
                durationMs = 800
            )
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Google Map
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            onMapClick = { selectedShop = null },
            properties = MapProperties(
                isMyLocationEnabled = false // Disable location to avoid permission issues
            )
        ) {
            // Coffee shop markers
            coffeeShops.forEach { shop ->
                MarkerComposable(
                    state = MarkerState(position = shop.coordinate),
                    onClick = {
                        selectedShop = shop
                        true
                    }
                ) {
                    val isSelected = selectedShop?.id == shop.id
                    
                    // Animated scale with spring animation
                    val animatedScale by animateFloatAsState(
                        targetValue = if (isSelected) 1.3f else 1.0f,
                        animationSpec = spring(
                            dampingRatio = Spring.DampingRatioMediumBouncy,
                            stiffness = Spring.StiffnessLow
                        ),
                        label = "marker_scale"
                    )
                    
                    // Animated color for the marker background
                    val animatedColor by animateColorAsState(
                        targetValue = if (isSelected) Color(0xFFE91E63) else Color(0xFFFF9800), // Pink when selected, orange otherwise
                        animationSpec = tween(durationMillis = 300),
                        label = "marker_color"
                    )
                    
                    // Animated text background opacity
                    val animatedTextAlpha by animateFloatAsState(
                        targetValue = if (isSelected) 1.0f else 0.9f,
                        animationSpec = tween(durationMillis = 300),
                        label = "text_alpha"
                    )
                    
                    // Animated text color
                    val animatedTextColor by animateColorAsState(
                        targetValue = if (isSelected) Color(0xFFE91E63) else Color.Black,
                        animationSpec = tween(durationMillis = 300),
                        label = "text_color"
                    )
                    
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .scale(animatedScale)
                            .zIndex(if (isSelected) 1f else 0f)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(animatedColor),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Place,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = shop.name,
                            modifier = Modifier
                                .background(
                                    color = Color.White.copy(alpha = animatedTextAlpha),
                                    shape = RoundedCornerShape(4.dp)
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = animatedTextColor
                        )
                    }
                }
            }
        }

        // Search bar and UI overlay
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            // Search bar
            SearchBar(
                searchText = searchText,
                onSearchTextChange = { searchText = it },
                onClearSearch = { searchText = "" }
            )

            // Search results
            AnimatedVisibility(
                visible = searchResults.isNotEmpty(),
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                SearchResults(
                    searchResults = searchResults,
                    onShopSelected = { shop ->
                        selectedShop = shop
                        searchText = ""
                    }
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Detail card
            selectedShop?.let { shop ->
                CoffeeShopDetailCard(
                    shop = shop,
                    onDismiss = { selectedShop = null }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchBar(
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    onClearSearch: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .zIndex(1f),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = "Search",
                tint = Color.Gray
            )
            Spacer(modifier = Modifier.width(8.dp))
            OutlinedTextField(
                value = searchText,
                onValueChange = onSearchTextChange,
                placeholder = { Text("Search for a coffee shop") },
                modifier = Modifier.weight(1f),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent
                )
            )
            if (searchText.isNotEmpty()) {
                IconButton(onClick = onClearSearch) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Clear search"
                    )
                }
            }
        }
    }
}

@Composable
fun SearchResults(
    searchResults: List<CoffeeShop>,
    onShopSelected: (CoffeeShop) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column {
            Text(
                text = "Suggestions",
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
            
            searchResults.forEachIndexed { index, shop ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onShopSelected(shop) }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFFF9800)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = shop.name,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = shop.address,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color.Gray
                        )
                    }
                }
                if (index < searchResults.size - 1) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 60.dp),
                        thickness = 0.5.dp,
                        color = Color.Gray.copy(alpha = 0.3f)
                    )
                }
            }
        }
    }
}

@Composable
fun CoffeeShopDetailCard(
    shop: CoffeeShop,
    onDismiss: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            // Header with close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = shop.name,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Close",
                        tint = Color.Gray
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Address
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = "Address",
                    tint = Color.Gray,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = shop.address,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Phone
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Phone,
                    contentDescription = "Phone",
                    tint = Color.Gray,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = shop.phone,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // View More button
            Button(
                onClick = { /* TODO: Navigate to detail view */ },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Blue
                )
            ) {
                Text(
                    text = "View More",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
} 