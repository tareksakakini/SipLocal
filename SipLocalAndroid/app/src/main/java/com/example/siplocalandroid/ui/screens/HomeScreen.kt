package com.example.siplocalandroid.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.example.siplocalandroid.ui.screens.tabs.*
import com.example.siplocalandroid.ui.theme.SipLocalAndroidTheme
import com.example.siplocalandroid.data.CoffeeShop
import com.example.siplocalandroid.data.DataService
import androidx.compose.ui.platform.LocalContext

@Composable
fun HomeScreen(onSignOut: () -> Unit) {
    val navController = rememberNavController()
    val currentRoute = currentRoute(navController)
    
    Scaffold(
        bottomBar = { 
            // Hide bottom navigation on detail screen
            if (currentRoute != null && !currentRoute.startsWith("detail/")) {
                BottomNavigationBar(navController)
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.padding(paddingValues)) {
            NavigationHost(navController = navController, onSignOut = onSignOut)
        }
    }
}

@Composable
fun BottomNavigationBar(navController: NavController) {
    val items = listOf(
        NavigationItem("Explore", Icons.Default.Search, "explore"),
        NavigationItem("Favorites", Icons.Default.Favorite, "favorites"),
        NavigationItem("Order", Icons.Default.ShoppingCart, "order"),
        NavigationItem("Passport", Icons.Default.Home, "passport"),
        NavigationItem("Profile", Icons.Default.Person, "profile")
    )

    NavigationBar {
        val currentRoute = currentRoute(navController)
        items.forEach { item ->
            NavigationBarItem(
                icon = { Icon(item.icon, contentDescription = item.title) },
                label = { Text(item.title) },
                selected = currentRoute == item.route,
                onClick = {
                    navController.navigate(item.route) {
                        // Pop up to the start destination of the graph to
                        // avoid building up a large stack of destinations
                        // on the back stack as users select items
                        navController.graph.startDestinationRoute?.let { route ->
                            popUpTo(route) {
                                saveState = true
                            }
                        }
                        // Avoid multiple copies of the same destination when
                        // reselecting the same item
                        launchSingleTop = true
                        // Restore state when reselecting a previously selected item
                        restoreState = true
                    }
                }
            )
        }
    }
}

@Composable
fun NavigationHost(navController: NavHostController, onSignOut: () -> Unit) {
    val context = LocalContext.current
    
    NavHost(navController = navController, startDestination = "explore") {
        composable("explore") { 
            ExploreScreen(
                onNavigateToDetail = { shop ->
                    navController.navigate("detail/${shop.id}")
                }
            )
        }
        composable("detail/{shopId}") { backStackEntry ->
            val shopId = backStackEntry.arguments?.getString("shopId")
            val shop = shopId?.let { DataService.getCoffeeShopById(context, it) }
            
            if (shop != null) {
                CoffeeShopDetailScreen(
                    shop = shop,
                    onBackClick = { navController.popBackStack() },
                    onMenuClick = { 
                        // TODO: Navigate to menu screen when it's implemented
                        // navController.navigate("menu/${shop.id}")
                    }
                )
            }
        }
        composable("favorites") { FavoritesScreen(navController = navController) }
        composable("order") { OrderScreen() }
        composable("passport") { PassportScreen() }
        composable("profile") { ProfileScreen(onSignOut = onSignOut) }
    }
}

data class NavigationItem(val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector, val route: String)

@Composable
fun currentRoute(navController: NavController): String? {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    return navBackStackEntry?.destination?.route
}

@Preview(showBackground = true)
@Composable
fun HomeScreenPreview() {
    SipLocalAndroidTheme {
        HomeScreen(onSignOut = {})
    }
} 