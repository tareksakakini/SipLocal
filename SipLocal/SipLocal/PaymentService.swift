import Foundation
import FirebaseFunctions

// A simple struct to represent a successful transaction
struct TransactionResult {
    let transactionId: String
    let message: String
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
    func processPayment(nonce: String, amount: Double, merchantId: String, oauthToken: String, cartItems: [CartItem], customerName: String, customerEmail: String) async -> Result<TransactionResult, PaymentError> {
        // Convert dollars to cents for Square API (multiply by 100)
        let amountInCents = Int(amount * 100)
        
        print("Calling Firebase function with nonce: \(nonce)")
        print("Calling Firebase function with amount: \(amount) dollars (\(amountInCents) cents)")
        print("Calling Firebase function with merchantId: \(merchantId)")
        print("Calling Firebase function with oauth_token: \(oauthToken.prefix(10))...")
        
        // Prepare cart items for backend
        let itemsForBackend = cartItems.map { item in
            return [
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100), // price in cents
                "customizations": item.customizations ?? ""
            ]
        }
        
        let callData: [String: Any] = [
            "nonce": nonce,
            "amount": amountInCents,
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail
        ]
        print("Calling Firebase function with data: \(callData)")
        
        do {
            // Call the Firebase function
            let result = try await functions.httpsCallable("processPayment").call(callData)
            
            // Parse the response
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success == true,
               let transactionId = data["transactionId"] as? String {
                
                let transactionResult = TransactionResult(
                    transactionId: transactionId,
                    message: "Payment successful!"
                )
                print("Firebase function returned success: \(transactionId)")
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
} 