import Foundation
import FirebaseFunctions
import Stripe
import PassKit

// A simple struct to represent a successful transaction
struct TransactionResult {
    let transactionId: String
    let message: String
    let receiptUrl: String? // Add receiptUrl to transaction result
    let orderId: String? // Square order ID for status fetching
    let status: String? // Payment status (AUTHORIZED, SUBMITTED, etc.)
}

// A simple enum for our payment errors
enum PaymentError: Error, LocalizedError {
    case networkError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "A network error occurred. Please check your connection and try again."
        case .serverError(let message):
            return message
        }
    }
}

class PaymentService {
    private let functions = Functions.functions()
    
    // This function calls our Firebase Cloud Function to process the payment
    func processPayment(nonce: String, amount: Double, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String, userId: String, coffeeShop: CoffeeShop, pickupTime: Date? = nil) async -> Result<TransactionResult, PaymentError> {
        // Convert dollars to cents for Square API (multiply by 100)
        let amountInCents = Int(amount * 100)
        
        print("Calling Firebase function with nonce: \(nonce)")
        print("Calling Firebase function with amount: \(amount) dollars (\(amountInCents) cents)")
        print("Calling Firebase function with merchantId: \(merchantId)")
        print("Calling Firebase function with oauth_token: \(oauthToken.prefix(10))...")
        
        // Prepare cart items for backend, include identifiers and selections for reordering
        let itemsForBackend = cartItems.map { item in
            return [
                "id": item.menuItemId,
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100),
                "customizations": item.customizations ?? "",
                "selectedSizeId": item.selectedSizeId ?? NSNull(),
                "selectedModifierIdsByList": item.selectedModifierIdsByList ?? NSNull()
            ] as [String : Any]
        }
        
        var callData: [String: Any] = [
            "nonce": nonce,
            "amount": amountInCents,
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail,
            "userId": userId,
            "coffeeShopData": coffeeShop.toDictionary()
        ]
        
        // Add pickup time if provided
        if let pickupTime = pickupTime {
            let formatter = ISO8601DateFormatter()
            callData["pickupTime"] = formatter.string(from: pickupTime)
        }
        print("Calling Firebase function with data: \(callData)")
        
        do {
            // Call the Firebase function
            let result = try await functions.httpsCallable("processPayment").call(callData)
            
            // Parse the response
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true,
               let transactionId = data["transactionId"] as? String {
                let receiptUrl = data["receiptUrl"] as? String // Parse receiptUrl if present
                let orderId = data["orderId"] as? String // Parse orderId if present
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Payment successful!",
                    receiptUrl: receiptUrl,
                    orderId: orderId,
                    status: data["status"] as? String
                )
                print("Firebase function returned success: \(transactionId), receiptUrl: \(receiptUrl ?? "nil")")
                return .success(transactionResult)
            } else {
                print("Firebase function returned unexpected response: \(result.data)")
                return .failure(.serverError("Unexpected response from server"))
            }
            
        } catch {
            print("Firebase function call failed: \(error)")
            return .failure(.serverError(error.localizedDescription))
        }
    }
    
    // Submit order to Square without processing payment
    func submitOrderWithExternalPayment(amount: Double, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String, userId: String, coffeeShop: CoffeeShop, pickupTime: Date? = nil) async -> Result<TransactionResult, PaymentError> {
        // Convert dollars to cents for Square API (multiply by 100)
        let amountInCents = Int(amount * 100)
        
        print("Calling Firebase function to submit order without payment")
        print("Amount: \(amount) dollars (\(amountInCents) cents)")
        print("MerchantId: \(merchantId)")
        print("OAuth token: \(oauthToken.prefix(10))...")
        
        // Prepare cart items for backend, include identifiers and selections for reordering
        let itemsForBackend = cartItems.map { item in
            return [
                "id": item.menuItemId,
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100),
                "customizations": item.customizations ?? "",
                "selectedSizeId": item.selectedSizeId ?? NSNull(),
                "selectedModifierIdsByList": item.selectedModifierIdsByList ?? NSNull()
            ] as [String : Any]
        }
        
        var callData: [String: Any] = [
            "amount": amountInCents,
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail,
            "userId": userId,
            "coffeeShopData": coffeeShop.toDictionary(),
            "externalPayment": true // Flag to indicate external payment handling
        ]
        
        // Add pickup time if provided
        if let pickupTime = pickupTime {
            let formatter = ISO8601DateFormatter()
            callData["pickupTime"] = formatter.string(from: pickupTime)
        }
        
        print("Calling Firebase function with external payment data: \(callData)")
        
        do {
            // Call the Firebase function for external payment orders
            let result = try await functions.httpsCallable("submitOrderWithExternalPayment").call(callData)
            
            // Parse the response
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true,
               let transactionId = data["transactionId"] as? String {
                let receiptUrl = data["receiptUrl"] as? String
                let orderId = data["orderId"] as? String
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Order submitted successfully! Payment handled externally.",
                    receiptUrl: receiptUrl,
                    orderId: orderId,
                    status: data["status"] as? String
                )
                print("Firebase function returned success for external payment order: \(transactionId)")
                return .success(transactionResult)
            } else {
                print("Firebase function returned unexpected response: \(result.data)")
                return .failure(.serverError("Unexpected response from server"))
            }
            
        } catch {
            print("Firebase function call failed for external payment: \(error)")
            return .failure(.serverError(error.localizedDescription))
        }
    }
    
    // Create authorized order with Stripe (payment intent created but not processed)
    func createAuthorizedOrderWithStripe(amount: Double, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String, userId: String, coffeeShop: CoffeeShop, pickupTime: Date? = nil) async -> Result<(TransactionResult, String?), PaymentError> {
        // Convert dollars to cents for Stripe API (multiply by 100)
        let amountInCents = Int(amount * 100)
        
        print("Processing Stripe payment and creating Square order")
        print("Amount: \(amount) dollars (\(amountInCents) cents)")
        print("MerchantId: \(merchantId)")
        print("OAuth token: \(oauthToken.prefix(10))...")
        
        // Prepare cart items for backend, include identifiers and selections for reordering
        let itemsForBackend = cartItems.map { item in
            return [
                "id": item.menuItemId,
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100),
                "customizations": item.customizations ?? "",
                "selectedSizeId": item.selectedSizeId ?? NSNull(),
                "selectedModifierIdsByList": item.selectedModifierIdsByList ?? NSNull()
            ] as [String : Any]
        }
        
        var callData: [String: Any] = [
            "amount": amountInCents,
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail,
            "userId": userId,
            "coffeeShopData": coffeeShop.toDictionary(),
            "paymentMethod": "stripe" // Flag to indicate Stripe payment processing
        ]
        
        // Add pickup time if provided
        if let pickupTime = pickupTime {
            let formatter = ISO8601DateFormatter()
            callData["pickupTime"] = formatter.string(from: pickupTime)
        }
        
        print("Calling Firebase function for Stripe payment with data: \(callData)")
        
        do {
            // Call the Firebase function for Stripe payment processing
            let result = try await functions.httpsCallable("processStripePayment").call(callData)
            
            // Parse the response
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true,
               let transactionId = data["transactionId"] as? String {
                let receiptUrl = data["receiptUrl"] as? String
                let orderId = data["orderId"] as? String
                let clientSecret = data["stripeClientSecret"] as? String
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Payment intent created. Complete payment to proceed.",
                    receiptUrl: receiptUrl,
                    orderId: orderId,
                    status: data["status"] as? String
                )
                print("Firebase function returned success for Stripe payment: \(transactionId)")
                print("Client secret received: \(clientSecret != nil ? "Yes" : "No")")
                return .success((transactionResult, clientSecret))
            } else {
                print("Firebase function returned unexpected response: \(result.data)")
                return .failure(.serverError("Unexpected response from server"))
            }
            
        } catch {
            print("Firebase function call failed for Stripe payment: \(error)")
            return .failure(.serverError(error.localizedDescription))
        }
    }
    
    // Complete the payment processing after authorization delay
    func completeStripePayment(clientSecret: String, transactionId: String) async -> Result<TransactionResult, PaymentError> {
        let functions = Functions.functions()
        let data = [
            "clientSecret": clientSecret,
            "transactionId": transactionId
        ]
        
        do {
            let result = try await functions.httpsCallable("completeStripePayment").call(data)
            
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true {
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Payment completed successfully!",
                    receiptUrl: data["receiptUrl"] as? String,
                    orderId: data["orderId"] as? String,
                    status: data["status"] as? String
                )
                print("Stripe payment completed successfully: \(transactionId)")
                return .success(transactionResult)
            } else {
                print("Failed to complete Stripe payment: \(result.data)")
                return .failure(.serverError("Failed to complete payment"))
            }
        } catch {
            print("Error completing Stripe payment: \(error)")
            return .failure(.serverError(error.localizedDescription))
        }
    }
    
    // Process Apple Pay payment through Stripe
    func processApplePayPayment(tokenId: String, amount: Int, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String, userId: String, coffeeShop: CoffeeShop, pickupTime: Date? = nil) async -> Result<TransactionResult, PaymentError> {
        
        print("🍎💳 PaymentService: Processing Apple Pay payment through Stripe")
        print("🍎💳 PaymentService: Amount: \(amount) cents")
        print("🍎💳 PaymentService: MerchantId: \(merchantId)")
        print("🍎💳 PaymentService: OAuth token: \(oauthToken.prefix(10))...")
        print("🍎💳 PaymentService: Token ID: \(tokenId)")
        print("🍎💳 PaymentService: Customer: \(customerName) (\(customerEmail))")
        print("🍎💳 PaymentService: Coffee shop: \(coffeeShop.name)")
        
        // Prepare cart items for backend
        let itemsForBackend = cartItems.map { item in
            return [
                "id": item.menuItemId,
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100),
                "customizations": item.customizations ?? "",
                "selectedSizeId": item.selectedSizeId ?? NSNull(),
                "selectedModifierIdsByList": item.selectedModifierIdsByList ?? NSNull()
            ] as [String : Any]
        }
        
        var callData: [String: Any] = [
            "amount": amount, // Already in cents
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail,
            "userId": userId,
            "coffeeShopData": coffeeShop.toDictionary(),
            "paymentMethod": "apple_pay",
            "tokenId": tokenId // Send Stripe Token ID instead of raw data
        ]
        
        // Add pickup time if provided
        if let pickupTime = pickupTime {
            let formatter = ISO8601DateFormatter()
            callData["pickupTime"] = formatter.string(from: pickupTime)
        }
        
        print("🍎💳 PaymentService: Calling Firebase function for Apple Pay payment")
        print("🍎💳 PaymentService: Call data prepared with \(callData.keys.count) keys")
        
        do {
            // Call the Firebase function for Apple Pay payment processing
            print("🍎💳 PaymentService: Invoking processApplePayPayment Firebase function...")
            let result = try await functions.httpsCallable("processApplePayPayment").call(callData)
            
            print("🍎💳 PaymentService: Firebase function response received")
            print("🍎💳 PaymentService: Response data: \(result.data)")
            
            // Parse the response
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true,
               let transactionId = data["transactionId"] as? String {
                let receiptUrl = data["receiptUrl"] as? String
                let orderId = data["orderId"] as? String
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Apple Pay payment successful!",
                    receiptUrl: receiptUrl,
                    orderId: orderId,
                    status: data["status"] as? String
                )
                print("✅ PaymentService: Firebase function returned success for Apple Pay payment: \(transactionId)")
                return .success(transactionResult)
            } else {
                print("❌ PaymentService: Firebase function returned unexpected response: \(result.data)")
                return .failure(.serverError("Unexpected response from server"))
            }
            
        } catch {
            print("❌ PaymentService: Firebase function call failed for Apple Pay payment: \(error)")
            if let error = error as NSError? {
                print("❌ PaymentService: Error domain: \(error.domain)")
                print("❌ PaymentService: Error code: \(error.code)")
                print("❌ PaymentService: Error userInfo: \(error.userInfo)")
            }
            return .failure(.serverError(error.localizedDescription))
        }
    }
    
    // MARK: - Apple Pay Capture
    
    func captureApplePayPayment(transactionId: String) async -> Result<String, PaymentError> {
        print("🍎💳 PaymentService: Capturing Apple Pay payment")
        print("  - Transaction ID: \(transactionId)")
        
        let functions = Functions.functions()
        let data: [String: Any] = ["transactionId": transactionId]
        
        do {
            let result = try await functions.httpsCallable("captureApplePayPaymentManual").call(data)
            
            if let resultData = result.data as? [String: Any],
               let success = resultData["success"] as? Bool,
               let message = resultData["message"] as? String,
               success {
                print("✅ PaymentService: Apple Pay payment captured successfully")
                return .success(message)
            } else {
                print("❌ PaymentService: Apple Pay capture returned unexpected response")
                return .failure(.serverError("Failed to capture Apple Pay payment"))
            }
        } catch {
            print("❌ PaymentService: Apple Pay capture failed: \(error)")
            return .failure(.serverError(error.localizedDescription))
        }
    }
} 