import Foundation
import PassKit
import Combine
import ObjectiveC

class ApplePayService: NSObject, ObservableObject {
    @Published var isApplePayAvailable = false
    @Published var isProcessingPayment = false
    
    private let paymentService = PaymentService()
    private let tokenService = TokenService()
    private var paymentCompletion: ((PKPaymentToken?) -> Void)?
    
    override init() {
        super.init()
        checkApplePayAvailability()
    }
    
    private func checkApplePayAvailability() {
        isApplePayAvailable = PKPaymentAuthorizationController.canMakePayments() &&
                              PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
    }
    
    private var supportedNetworks: [PKPaymentNetwork] {
        return [
            .visa,
            .masterCard,
            .amex,
            .discover
        ]
    }
    
    func createPaymentRequest(amount: Double, merchantId: String, shopName: String) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.siplocal.app" // Use the Apple Pay merchant identifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = [.capability3DS, .emv]
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        // Set the payment summary items
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: shopName, amount: NSDecimalNumber(value: amount)),
            PKPaymentSummaryItem(label: "SipLocal", amount: NSDecimalNumber(value: amount))
        ]
        
        return request
    }
    
    func presentApplePay(
        amount: Double,
        merchantId: String,
        shopName: String,
        completion: @escaping (PKPaymentToken?) -> Void
    ) {
        let paymentRequest = createPaymentRequest(amount: amount, merchantId: merchantId, shopName: shopName)
        let paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController.delegate = self
        
        // Store the completion handler
        self.paymentCompletion = completion
        
        paymentController.present { presented in
            if !presented {
                // Payment sheet failed to present
                completion(nil)
            }
        }
    }
    
    func processApplePayPayment(
        amount: Double,
        merchantId: String,
        oauthToken: String,
        cartItems: [CartItem],
        customerName: String,
        customerEmail: String,
        userId: String,
        coffeeShop: CoffeeShop,
        pickupTime: Date? = nil,
        paymentToken: PKPaymentToken
    ) async -> Result<TransactionResult, PaymentError> {
        // Convert dollars to cents for Square API (multiply by 100)
        let amountInCents = Int(amount * 100)
        
        // Prepare cart items for backend
        let itemsForBackend = cartItems.map { item in
            return [
                "name": item.menuItem.name,
                "quantity": item.quantity,
                "price": Int(item.itemPriceWithModifiers * 100), // price in cents
                "customizations": item.customizations ?? ""
            ]
        }
        
        // Convert payment token to base64 string for transmission
        let paymentData = paymentToken.paymentData.base64EncodedString()
        
        print("Apple Pay: Payment token data length: \(paymentToken.paymentData.count)")
        print("Apple Pay: Payment token type: \(paymentToken.paymentMethod.type.rawValue)")
        
        var callData: [String: Any] = [
            "nonce": paymentData, // Use the actual Apple Pay token
            "amount": amountInCents,
            "merchantId": merchantId,
            "oauth_token": oauthToken,
            "items": itemsForBackend,
            "customerName": customerName,
            "customerEmail": customerEmail,
            "userId": userId,
            "coffeeShopData": coffeeShop.toDictionary(),
            "paymentMethod": "apple_pay"
        ]
        
        // Add pickup time if provided
        if let pickupTime = pickupTime {
            let formatter = ISO8601DateFormatter()
            callData["pickupTime"] = formatter.string(from: pickupTime)
        }
        
        do {
            print("Apple Pay: Calling Firebase function with data: \(callData)")
            
            // Call the Firebase function
            let result = try await paymentService.functions.httpsCallable("processPayment").call(callData)
            
            print("Apple Pay: Firebase function response: \(result.data)")
            
            // Parse the response
            if let data = result.data as? [String: Any] {
                print("Apple Pay: Parsed response data: \(data)")
                
                if let success = data["success"] as? Bool {
                    if success {
                        let transactionId = data["transactionId"] as? String ?? "Unknown"
                        let message = data["message"] as? String ?? "Payment successful"
                        
                        print("Apple Pay: Payment successful - \(transactionId)")
                        
                        return .success(TransactionResult(
                            transactionId: transactionId,
                            message: message,
                            receiptUrl: nil,
                            orderId: nil
                        ))
                    } else {
                        let errorMessage = data["error"] as? String ?? "Payment failed"
                        print("Apple Pay: Payment failed - \(errorMessage)")
                        return .failure(PaymentError.paymentFailed(errorMessage))
                    }
                } else {
                    print("Apple Pay: No success field in response")
                    return .failure(PaymentError.invalidResponse)
                }
            } else {
                print("Apple Pay: Could not parse response data")
                return .failure(PaymentError.invalidResponse)
            }
        } catch {
            print("Apple Pay: Network error - \(error.localizedDescription)")
            return .failure(PaymentError.networkError(error.localizedDescription))
        }
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension ApplePayService: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Call the completion handler with the payment token
        paymentCompletion?(payment.token)
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        // Clear the completion handler
        paymentCompletion = nil
    }
} 