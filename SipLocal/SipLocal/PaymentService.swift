import Foundation
import FirebaseFunctions
import Stripe

// A simple struct to represent a successful transaction
struct TransactionResult {
    let transactionId: String
    let message: String
    let receiptUrl: String? // Add receiptUrl to transaction result
    let orderId: String? // Square order ID for status fetching
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
                    orderId: orderId
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
                    orderId: orderId
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
    
    // Process payment with Stripe and create order in Square
    func processPaymentWithStripe(amount: Double, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String, userId: String, coffeeShop: CoffeeShop, pickupTime: Date? = nil) async -> Result<(TransactionResult, String?), PaymentError> {
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
                    orderId: orderId
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
} 