import SwiftUI

struct PaymentResultView: View {
    let isSuccess: Bool
    let transactionId: String?
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Success/Failure Icon
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(isSuccess ? .green : .red)
                
                VStack(spacing: 16) {
                    // Title
                    Text(isSuccess ? "Payment Successful!" : "Payment Failed")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Message
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Transaction ID (if success)
                    if isSuccess, let transactionId = transactionId {
                        VStack(spacing: 8) {
                            Text("Transaction ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(transactionId)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if isSuccess {
                        Button(action: onDismiss) {
                            Text("Continue Shopping")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button(action: onDismiss) {
                                Text("Try Again")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: onDismiss) {
                                Text("Go Back")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// Preview
struct PaymentResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentResultView(
                isSuccess: true,
                transactionId: "sq0idp-1234567890",
                message: "Your payment has been processed successfully. You'll receive a confirmation email shortly."
            ) {
                print("Dismissed")
            }
            .previewDisplayName("Success")
            
            PaymentResultView(
                isSuccess: false,
                transactionId: nil,
                message: "Your payment could not be processed. Please check your payment method and try again."
            ) {
                print("Dismissed")
            }
            .previewDisplayName("Failure")
        }
    }
}