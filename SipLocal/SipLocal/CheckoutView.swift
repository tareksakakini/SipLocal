import SwiftUI
import SquareInAppPaymentsSDK
import Combine

struct CheckoutView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var authManager: AuthenticationManager // <-- Inject authManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isProcessingPayment = false
    @State private var paymentResult: String = ""
    @State private var showingCardEntry = false
    @State private var showingPaymentResult = false
    @State private var paymentSuccess = false
    @State private var transactionId: String?
    @State private var completedOrderItems: [CartItem] = []
    @State private var completedOrderTotal: Double = 0.0
    @State private var completedOrderShop: CoffeeShop?
    @State private var userData: UserData? = nil // <-- Store user data
    @State private var selectedPickupTime = Date().addingTimeInterval(5 * 60) // Default to 5 minutes from now
    @State private var showingTimePicker = false
    @State private var showingClosedShopAlert = false
    
    // Use @StateObject to create and manage the delegate
    @StateObject private var cardEntryDelegate = SquareCardEntryDelegate()
    
    // Add an instance of our payment service
    private let paymentService = PaymentService()
    private let tokenService = TokenService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Cart Summary
                ScrollView {
                    VStack(spacing: 16) {
                        // Order Summary Header
                        HStack {
                            Text("Order Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Coffee Shop Header
                        if let firstItem = cartManager.items.first {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "house.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(firstItem.shop.name)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        
                        // Cart Items
                        LazyVStack(spacing: 12) {
                            ForEach(cartManager.items) { item in
                                CheckoutItemRow(cartItem: item)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Pickup Time Section
                        VStack(spacing: 12) {
                            Button(action: {
                                showingTimePicker = true
                            }) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pickup at")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(formatPickupTime(selectedPickupTime))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Chevron with subtle background
                                    ZStack {
                                        Circle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                // Payment Section
                VStack(spacing: 16) {
                    Divider()
                    
                    // Total
                    HStack {
                        Text("Total")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("$\(cartManager.totalPrice, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    
                    // Checkout Button (External Payment)
                    Button(action: {
                        // Check if shop is closed before allowing checkout
                        if let firstItem = cartManager.items.first,
                           let isOpen = cartManager.isShopOpen(shop: firstItem.shop),
                           !isOpen {
                            showingClosedShopAlert = true
                            return
                        }
                        
                        // Submit order without payment processing
                        submitOrderWithExternalPayment()
                    }) {
                        HStack {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            } else {
                                Text("Place Order")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessingPayment ? Color.gray : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessingPayment)
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                }
                .background(Color(.systemGray6))
            }
            .background(Color(.systemGray6))
            .navigationTitle("Checkout")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCardEntry) {
            CardEntryView(delegate: self.cardEntryDelegate)
        }
        .sheet(isPresented: $showingTimePicker) {
            PickupTimeSelectionView(
                selectedTime: $selectedPickupTime, 
                isPresented: $showingTimePicker,
                businessHoursInfo: cartManager.items.first.flatMap { cartManager.shopBusinessHours[$0.shop.id] }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .alert("Shop is Closed", isPresented: $showingClosedShopAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This coffee shop is currently closed. Please try again during business hours.")
        }
        .sheet(isPresented: $showingPaymentResult) {
            PaymentResultView(
                isSuccess: paymentSuccess,
                transactionId: transactionId,
                message: paymentResult,
                coffeeShop: paymentSuccess ? completedOrderShop : nil,
                orderItems: paymentSuccess ? completedOrderItems : nil,
                totalAmount: paymentSuccess ? completedOrderTotal : nil,
                pickupTime: paymentSuccess ? selectedPickupTime : nil,
                onDismiss: {
                    showingPaymentResult = false
                    if paymentSuccess {
                        // Switch to Explore tab first, then dismiss checkout
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToExploreTab"), object: nil)
                        
                        // Dismiss the checkout view after a brief delay to ensure tab switch completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        // For failed payments, just dismiss normally
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                onTryAgain: paymentSuccess ? nil : {
                    // For failed payments, show card entry again
                    showingPaymentResult = false
                    showingCardEntry = true
                },
                onCancel: paymentSuccess ? {
                    // Handle order cancellation
                    showingPaymentResult = false
                    presentationMode.wrappedValue.dismiss()
                } : nil
            )
        }
        .onReceive(cardEntryDelegate.$cardDetails) { cardDetails in
            if let details = cardDetails {
                // We have the nonce, now process the payment
                processPayment(nonce: details.nonce)
            }
        }
        .onReceive(cardEntryDelegate.$wasCancelled) { wasCancelled in
            if wasCancelled {
                self.paymentResult = "Card entry was canceled."
                self.showingCardEntry = false
            }
        }
        .onAppear {
            // Fetch business hours for the shop in cart
            if let firstItem = cartManager.items.first {
                Task {
                    await cartManager.fetchBusinessHours(for: firstItem.shop)
                }
            }
        }
    }
    
    private func processPayment(nonce: String) {
        isProcessingPayment = true
        paymentResult = "Processing payment..."
        guard let firstItem = cartManager.items.first else {
            paymentResult = "No items in cart"
            isProcessingPayment = false
            return
        }
        let merchantId = firstItem.shop.merchantId
        // Fetch user data before payment
        guard let userId = authManager.currentUser?.uid else {
            paymentResult = "User not logged in."
            isProcessingPayment = false
            return
        }
        authManager.getUserData(userId: userId) { userData, error in
            guard let userData = userData else {
                DispatchQueue.main.async {
                    self.paymentResult = "Failed to fetch user info: \(error ?? "Unknown error")"
                    self.isProcessingPayment = false
                }
                return
            }
            Task {
                do {
                    let credentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
                    print("Debug - Sending to Firebase:")
                    print("  nonce: \(nonce)")
                    print("  amount: \(cartManager.totalPrice)")
                    print("  merchantId: \(merchantId)")
                    print("  oauth_token: \(credentials.oauth_token.prefix(10)))...")
                    // Now process the payment with the fetched tokens and user info
                    let result = await paymentService.processPayment(
                        nonce: nonce,
                        amount: cartManager.totalPrice,
                        merchantId: merchantId,
                        oauthToken: credentials.oauth_token,
                        cartItems: cartManager.items,
                        customerName: userData.fullName,
                        customerEmail: userData.email,
                        userId: userId,
                        coffeeShop: cartManager.items.first!.shop,
                        pickupTime: selectedPickupTime
                    )
                    await MainActor.run {
                        switch result {
                        case .success(let transaction):
                            paymentResult = transaction.message
                            paymentSuccess = true
                            transactionId = transaction.transactionId
                            completedOrderItems = cartManager.items
                            completedOrderTotal = cartManager.totalPrice
                            completedOrderShop = cartManager.items.first?.shop
                            // Orders are now stored in Firestore by the backend
                            // Refresh orders to show the new order
                            Task {
                                await orderManager.refreshOrders()
                            }
                            cartManager.clearCart()
                        case .failure(let error):
                            paymentResult = error.localizedDescription
                            paymentSuccess = false
                            transactionId = nil
                        }
                        isProcessingPayment = false
                        self.showingCardEntry = false
                        self.showingPaymentResult = true
                    }
                } catch {
                    await MainActor.run {
                        paymentResult = "Failed to retrieve payment credentials: \(error.localizedDescription)"
                        paymentSuccess = false
                        transactionId = nil
                        isProcessingPayment = false
                        self.showingCardEntry = false
                        self.showingPaymentResult = true
                    }
                }
            }
        }
    }
    
    private func submitOrderWithExternalPayment() {
        isProcessingPayment = true
        paymentResult = "Submitting order..."
        
        guard let firstItem = cartManager.items.first else {
            paymentResult = "No items in cart"
            isProcessingPayment = false
            return
        }
        
        let merchantId = firstItem.shop.merchantId
        
        // Fetch user data before submitting order
        guard let userId = authManager.currentUser?.uid else {
            paymentResult = "User not logged in."
            isProcessingPayment = false
            return
        }
        
        authManager.getUserData(userId: userId) { userData, error in
            guard let userData = userData else {
                DispatchQueue.main.async {
                    self.paymentResult = "Failed to fetch user info: \(error ?? "Unknown error")"
                    self.isProcessingPayment = false
                }
                return
            }
            
            Task {
                do {
                    let credentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
                    print("Debug - Submitting order to Square without payment:")
                    print("  amount: \(cartManager.totalPrice)")
                    print("  merchantId: \(merchantId)")
                    print("  oauth_token: \(credentials.oauth_token.prefix(10))...")
                    
                    // Submit order with external payment flag
                    let result = await paymentService.submitOrderWithExternalPayment(
                        amount: cartManager.totalPrice,
                        merchantId: merchantId,
                        oauthToken: credentials.oauth_token,
                        cartItems: cartManager.items,
                        customerName: userData.fullName,
                        customerEmail: userData.email,
                        userId: userId,
                        coffeeShop: cartManager.items.first!.shop,
                        pickupTime: selectedPickupTime
                    )
                    
                    await MainActor.run {
                        switch result {
                        case .success(let transaction):
                            paymentResult = "Order submitted successfully! Payment will be handled externally."
                            paymentSuccess = true
                            transactionId = transaction.transactionId
                            completedOrderItems = cartManager.items
                            completedOrderTotal = cartManager.totalPrice
                            completedOrderShop = cartManager.items.first?.shop
                            // Orders are now stored in Firestore by the backend
                            // Refresh orders to show the new order
                            Task {
                                await orderManager.refreshOrders()
                            }
                            cartManager.clearCart()
                        case .failure(let error):
                            paymentResult = error.localizedDescription
                            paymentSuccess = false
                            transactionId = nil
                        }
                        isProcessingPayment = false
                        self.showingPaymentResult = true
                    }
                } catch {
                    await MainActor.run {
                        paymentResult = "Failed to submit order: \(error.localizedDescription)"
                        paymentSuccess = false
                        transactionId = nil
                        isProcessingPayment = false
                        self.showingPaymentResult = true
                    }
                }
            }
        }
    }
    
    private func formatPickupTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// 2. Create a UIViewControllerRepresentable to wrap the Square SDK's view controller
struct CardEntryView: UIViewControllerRepresentable {
    var delegate: SQIPCardEntryViewControllerDelegate
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Customize the card entry form theme
        let theme = SQIPTheme()
        theme.tintColor = .black
        theme.saveButtonTitle = "Pay"
        
        let cardEntryViewController = SQIPCardEntryViewController(theme: theme)
        cardEntryViewController.delegate = delegate
        
        let navigationController = UINavigationController(rootViewController: cardEntryViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
}


struct CheckoutItemRow: View {
    let cartItem: CartItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cartItem.menuItem.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let customizations = cartItem.customizations, !customizations.isEmpty {
                    Text(customizations)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("×\(cartItem.quantity)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("$\(cartItem.totalPrice, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct PickupTimeSelectionView: View {
    @Binding var selectedTime: Date
    @Binding var isPresented: Bool
    @State private var tempTime: Date
    let businessHoursInfo: BusinessHoursInfo?
    
    init(selectedTime: Binding<Date>, isPresented: Binding<Bool>, businessHoursInfo: BusinessHoursInfo? = nil) {
        self._selectedTime = selectedTime
        self._isPresented = isPresented
        self._tempTime = State(initialValue: selectedTime.wrappedValue)
        self.businessHoursInfo = businessHoursInfo
    }
    
    private var timeRange: ClosedRange<Date> {
        let now = Date()
        let calendar = Calendar.current
        
        // Get today's closing time
        let today = calendar.component(.weekday, from: now)
        let dayOfWeek = convertWeekdayToSquareFormat(today)
        
        if let businessHoursInfo = businessHoursInfo,
           let todayPeriods = businessHoursInfo.weeklyHours[dayOfWeek],
           !todayPeriods.isEmpty {
            
            // Find the latest closing time for today
            var latestClosingTime: (hour: Int, minute: Int) = (0, 0)
            var latestClosingTimeString = ""
            
            for period in todayPeriods {
                let closingTime = parseTimeString(period.endTime)
                let currentLatest = latestClosingTime.hour * 60 + latestClosingTime.minute
                let periodClosing = closingTime.hour * 60 + closingTime.minute
                
                print("Debug - Period: \(period.startTime) to \(period.endTime)")
                print("Debug - Parsed closing: \(closingTime.hour):\(closingTime.minute) (\(periodClosing) minutes)")
                print("Debug - Current latest: \(latestClosingTime.hour):\(latestClosingTime.minute) (\(currentLatest) minutes)")
                
                if periodClosing > currentLatest {
                    latestClosingTime = closingTime
                    latestClosingTimeString = period.endTime
                    print("Debug - New latest: \(latestClosingTime.hour):\(latestClosingTime.minute)")
                }
            }
            
            print("Debug - Final latest closing time: \(latestClosingTime.hour):\(latestClosingTime.minute)")
            
            // Create closing date for today
            var closingComponents = calendar.dateComponents([.year, .month, .day], from: now)
            closingComponents.hour = latestClosingTime.hour
            closingComponents.minute = latestClosingTime.minute
            closingComponents.second = 0
            
            if let todayClosing = calendar.date(from: closingComponents) {
                // Ensure closing time is after current time
                if todayClosing > now {
                    return now...todayClosing
                }
            }
        }
        
        // Fallback: allow up to 24 hours from now
        let maxTime = now.addingTimeInterval(24 * 60 * 60)
        return now...maxTime
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int) {
        // Handle empty or invalid time strings
        guard !timeString.isEmpty else { return (0, 0) }
        
        let components = timeString.split(separator: ":")
        guard components.count >= 2 else { return (0, 0) }
        
        let hour = Int(components[0]) ?? 0
        let minute = Int(components[1]) ?? 0
        
        // Validate hour and minute ranges
        let validHour = max(0, min(23, hour))
        let validMinute = max(0, min(59, minute))
        
        return (validHour, validMinute)
    }
    
    private func convertWeekdayToSquareFormat(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "SUN"
        case 2: return "MON"
        case 3: return "TUE"
        case 4: return "WED"
        case 5: return "THU"
        case 6: return "FRI"
        case 7: return "SAT"
        default: return "MON"
        }
    }
    
    private func getClosingTimeString() -> String? {
        guard let businessHoursInfo = businessHoursInfo else { return nil }
        
        let today = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = convertWeekdayToSquareFormat(today)
        
        guard let todayPeriods = businessHoursInfo.weeklyHours[dayOfWeek],
              !todayPeriods.isEmpty else { return nil }
        
        // Find the latest closing time
        var latestClosingTime: (hour: Int, minute: Int) = (0, 0)
        var latestClosingTimeString = ""
        
        for period in todayPeriods {
            let closingTime = parseTimeString(period.endTime)
            let currentLatest = latestClosingTime.hour * 60 + latestClosingTime.minute
            let periodClosing = closingTime.hour * 60 + closingTime.minute
            
            if periodClosing > currentLatest {
                latestClosingTime = closingTime
                latestClosingTimeString = period.endTime
            }
        }
        
        // For debugging, let's also show the original time string
        print("Debug - Original closing time string: \(latestClosingTimeString)")
        print("Debug - Parsed closing time: \(latestClosingTime.hour):\(latestClosingTime.minute)")
        
        // Format the time for display
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var components = DateComponents()
        components.hour = latestClosingTime.hour
        components.minute = latestClosingTime.minute
        
        if let timeDate = Calendar.current.date(from: components) {
            return formatter.string(from: timeDate)
        }
        
        return "\(latestClosingTime.hour):\(String(format: "%02d", latestClosingTime.minute))"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $tempTime,
                    in: timeRange,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                // Show closing time info if available
                if let closingTimeString = getClosingTimeString() {
                    Text("Shop closes at \(closingTimeString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Pickup Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Ensure the selected time is on today's date
                        let calendar = Calendar.current
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: tempTime)
                        let todayWithSelectedTime = calendar.dateBySettingTime(of: Date(), hour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0)
                        selectedTime = todayWithSelectedTime ?? tempTime
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

extension Calendar {
    func dateBySettingTime(of date: Date, hour: Int, minute: Int) -> Date? {
        var components = self.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return self.date(from: components)
    }
}

// Preview
struct CheckoutView_Previews: PreviewProvider {
    static var previews: some View {
        CheckoutView()
            .environmentObject(CartManager())
            .environmentObject(OrderManager())
    }
} 