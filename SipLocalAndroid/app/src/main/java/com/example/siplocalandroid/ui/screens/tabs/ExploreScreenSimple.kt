package com.example.siplocalandroid.ui.screens.tabs

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.example.siplocalandroid.data.CoffeeShop
import com.example.siplocalandroid.data.DataService

@Composable
fun ExploreScreenSimple() {
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

    Box(modifier = Modifier.fillMaxSize()) {
        // Placeholder for map
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Gray.copy(alpha = 0.3f)),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "🗺️",
                    style = MaterialTheme.typography.displayLarge
                )
                Text(
                    text = "Map View",
                    style = MaterialTheme.typography.headlineMedium,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = "Add Google Maps API key to enable map",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.Gray,
                    textAlign = TextAlign.Center
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                // Show coffee shops as a simple list
                LazyColumn {
                    items(coffeeShops) { shop ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp)
                                .clickable { selectedShop = shop },
                            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp)
                            ) {
                                Text(
                                    text = shop.name,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = shop.address,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color.Gray
                                )
                            }
                        }
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
                    onDismiss = { selectedShop = null },
                    onNavigateToDetail = {}
                )
            }
        }
    }
} 