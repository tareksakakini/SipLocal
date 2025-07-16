package com.example.siplocalandroid.data

import android.content.Context
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import java.io.IOException

class DataService {
    companion object {
        private var cachedCoffeeShops: List<CoffeeShop>? = null
        
        fun loadCoffeeShops(context: Context): List<CoffeeShop> {
            // Return cached data if available
            cachedCoffeeShops?.let { return it }
            
            try {
                val jsonString = context.assets.open("coffee_shops.json").bufferedReader().use { it.readText() }
                val json = Json { ignoreUnknownKeys = true }
                val coffeeShops = json.decodeFromString<List<CoffeeShop>>(jsonString)
                cachedCoffeeShops = coffeeShops
                return coffeeShops
            } catch (e: IOException) {
                e.printStackTrace()
                return emptyList()
            } catch (e: Exception) {
                e.printStackTrace()
                return emptyList()
            }
        }
        
        fun getCoffeeShopById(context: Context, id: String): CoffeeShop? {
            return loadCoffeeShops(context).find { it.id == id }
        }
    }
} 