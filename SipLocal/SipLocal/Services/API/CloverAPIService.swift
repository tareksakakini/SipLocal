import Foundation

class CloverAPIService: POSServiceProtocol {
    static let shared = CloverAPIService()
    private let tokenService = TokenService()
    
    private init() {}
    
    // MARK: - Main Function to Fetch Menu Data
    
    func fetchMenuData(for shop: CoffeeShop) async throws -> [MenuCategory] {
        print("🔍 CloverAPIService: Starting menu fetch for shop: \(shop.name) (merchantId: \(shop.merchantId))")
        
        do {
            // First, fetch the merchant tokens from the backend
            print("🔍 CloverAPIService: Fetching tokens from backend...")
            let credentials = try await tokenService.getCloverCredentials(merchantId: shop.merchantId)
            print("🔍 CloverAPIService: Successfully got credentials, fetching menu...")
            
            // Fetch categories, items, and modifier groups in parallel
            async let categoriesTask = fetchCategories(credentials: credentials)
            async let itemsTask = fetchItems(credentials: credentials)
            async let modifierGroupsTask = fetchModifierGroups(credentials: credentials)
            
            let (categories, items, modifierGroups) = try await (categoriesTask, itemsTask, modifierGroupsTask)
            
            print("🔍 CloverAPIService: Successfully fetched \(categories.count) categories, \(items.count) items, \(modifierGroups.count) modifier groups")
            
            let menuCategories = processCloverData(categories: categories, items: items, modifierGroups: modifierGroups)
            print("🔍 CloverAPIService: Successfully processed into \(menuCategories.count) menu categories")
            
            return menuCategories
        } catch {
            print("❌ CloverAPIService: Error fetching menu data for \(shop.name): \(error)")
            throw error
        }
    }
    
    // MARK: - Order Status Fetching
    
    func fetchOrderStatus(orderId: String, merchantId: String) async throws -> OrderStatus {
        do {
            // First, fetch the merchant tokens from the backend
            let credentials = try await tokenService.getCloverCredentials(merchantId: merchantId)
            
            let cloverOrder = try await fetchCloverOrder(orderId: orderId, credentials: credentials)
            
            // Convert Clover order state to our OrderStatus
            let orderStatus = convertCloverOrderToOrderStatus(cloverOrder)
            
            return orderStatus
            
        } catch {
            print("❌ CloverAPIService: Error fetching order status: \(error)")
            throw error
        }
    }
    
    // MARK: - Business Hours Fetching
    
    func fetchBusinessHours(for shop: CoffeeShop) async throws -> BusinessHoursInfo? {
        print("🔍 CloverAPIService: Starting business hours fetch for shop: \(shop.name) (merchantId: \(shop.merchantId))")
        
        do {
            // First, fetch the merchant tokens from the backend
            let credentials = try await tokenService.getCloverCredentials(merchantId: shop.merchantId)
            
            // Fetch business hours from Clover
            let cloverHours = try await fetchCloverBusinessHours(credentials: credentials)
            print("🔍 CloverAPIService: Found \(cloverHours.count) business hour entries for \(shop.name)")
            
            let businessHoursInfo = processCloverOpeningHours(cloverHours)
            print("🔍 CloverAPIService: Successfully processed business hours for \(shop.name)")
            
            return businessHoursInfo
            
        } catch {
            print("❌ CloverAPIService: Error fetching business hours for \(shop.name): \(error)")
            throw error
        }
    }
    
    // MARK: - Private Functions
    
    private func fetchCategories(credentials: CloverCredentials) async throws -> [CloverCategory] {
        // Try sandbox environment first - most common for development
        let baseURL = "https://sandbox.dev.clover.com/v3/merchants/\(credentials.merchantId)/categories"
        
        guard let url = URL(string: baseURL) else {
            throw CloverAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloverAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Log the actual response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ CloverAPIService: Categories API error response: \(responseString)")
                }
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(CloverErrorResponse.self, from: data) {
                    throw CloverAPIError.apiError(errorResponse.message)
                }
                throw CloverAPIError.httpError(httpResponse.statusCode)
            }
            
            let categoriesResponse = try JSONDecoder().decode(CloverCategoriesResponse.self, from: data)
            return categoriesResponse.elements ?? []
            
        } catch {
            if error is CloverAPIError {
                throw error
            }
            throw CloverAPIError.networkError(error)
        }
    }
    
    private func fetchItems(credentials: CloverCredentials) async throws -> [CloverItem] {
        // Try sandbox environment first - most common for development  
        let baseURL = "https://sandbox.dev.clover.com/v3/merchants/\(credentials.merchantId)/items?expand=categories,modifierGroups"
        
        guard let url = URL(string: baseURL) else {
            throw CloverAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloverAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Log the actual response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ CloverAPIService: Items API error response: \(responseString)")
                }
                if let errorResponse = try? JSONDecoder().decode(CloverErrorResponse.self, from: data) {
                    throw CloverAPIError.apiError(errorResponse.message)
                }
                throw CloverAPIError.httpError(httpResponse.statusCode)
            }
            
            let itemsResponse = try JSONDecoder().decode(CloverItemsResponse.self, from: data)
            return itemsResponse.elements ?? []
            
        } catch {
            if error is CloverAPIError {
                throw error
            }
            throw CloverAPIError.networkError(error)
        }
    }
    
    private func fetchModifierGroups(credentials: CloverCredentials) async throws -> [CloverModifierGroup] {
        // Try sandbox environment first - most common for development
        let baseURL = "https://sandbox.dev.clover.com/v3/merchants/\(credentials.merchantId)/modifier_groups?expand=modifiers"
        
        guard let url = URL(string: baseURL) else {
            throw CloverAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloverAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(CloverErrorResponse.self, from: data) {
                    throw CloverAPIError.apiError(errorResponse.message)
                }
                throw CloverAPIError.httpError(httpResponse.statusCode)
            }
            
            let modifierGroupsResponse = try JSONDecoder().decode(CloverModifierGroupsResponse.self, from: data)
            return modifierGroupsResponse.elements ?? []
            
        } catch {
            if error is CloverAPIError {
                throw error
            }
            throw CloverAPIError.networkError(error)
        }
    }
    
    private func processCloverData(categories: [CloverCategory], items: [CloverItem], modifierGroups: [CloverModifierGroup]) -> [MenuCategory] {
        // Create modifier group mapping for quick lookup
        let modifierGroupMapping: [String: MenuItemModifierList] = Dictionary(uniqueKeysWithValues: modifierGroups.compactMap { cloverGroup in
            guard let modifiers = cloverGroup.modifiers?.elements else { return nil }
            
            let appModifiers = modifiers.compactMap { cloverModifier -> MenuItemModifier? in
                guard cloverModifier.available != false else { return nil }
                
                let priceInCents = cloverModifier.price ?? 0
                let price = Double(priceInCents) / 100.0
                
                return MenuItemModifier(
                    id: cloverModifier.id,
                    name: cloverModifier.name,
                    price: price,
                    isDefault: false // Clover doesn't have a direct equivalent
                )
            }
            
            let appModifierList = MenuItemModifierList(
                id: cloverGroup.id,
                name: cloverGroup.name,
                selectionType: (cloverGroup.maxAllowed ?? 1) > 1 ? "MULTIPLE" : "SINGLE",
                minSelections: cloverGroup.minRequired ?? 0,
                maxSelections: cloverGroup.maxAllowed ?? 1,
                modifiers: appModifiers
            )
            
            return (cloverGroup.id, appModifierList)
        })
        
        // Process categories and their items
        var processedItemIds = Set<String>()
        var menuCategories: [MenuCategory] = []
        
        for category in categories {
            // Find items belonging to this category
            let categoryItems = items.compactMap { cloverItem -> MenuItem? in
                // Skip hidden items
                guard cloverItem.hidden != true else { return nil }
                
                // Check if item belongs to this category
                let itemCategoryIds = cloverItem.categories?.elements?.map { $0.id } ?? []
                guard itemCategoryIds.contains(category.id) else { return nil }
                
                // Mark this item as processed
                processedItemIds.insert(cloverItem.id)
                
                return convertCloverItemToMenuItem(cloverItem, modifierGroupMapping: modifierGroupMapping)
            }
            
            if !categoryItems.isEmpty {
                menuCategories.append(MenuCategory(name: category.name, items: categoryItems))
            }
        }
        
        // Add any remaining items that weren't assigned to categories
        let remainingItems = items.compactMap { cloverItem -> MenuItem? in
            guard cloverItem.hidden != true else { return nil }
            guard !processedItemIds.contains(cloverItem.id) else { return nil }
            
            return convertCloverItemToMenuItem(cloverItem, modifierGroupMapping: modifierGroupMapping)
        }
        
        if !remainingItems.isEmpty {
            menuCategories.append(MenuCategory(name: "Other", items: remainingItems))
        }
        
        // Sort by name for consistent ordering
        return menuCategories.sorted { $0.name < $1.name }
    }
    
    private func convertCloverItemToMenuItem(_ cloverItem: CloverItem, modifierGroupMapping: [String: MenuItemModifierList]) -> MenuItem {
        // Convert price from cents to dollars
        let priceInCents = cloverItem.price ?? 0
        let price = Double(priceInCents) / 100.0
        
        // Get modifier lists for this item
        let modifierLists = cloverItem.modifierGroups?.elements?.compactMap { modifierGroup in
            return modifierGroupMapping[modifierGroup.id]
        } ?? []
        
        // Extract legacy customizations for backward compatibility
        let customizations = extractCustomizationTypes(from: modifierLists)
        
        return MenuItem(
            id: cloverItem.id,
            name: cloverItem.name,
            price: price,
            variations: nil, // Clover doesn't have variations like Square
            customizations: customizations,
            imageURL: nil, // Clover images would require separate API call
            modifierLists: modifierLists
        )
    }
    
    private func extractCustomizationTypes(from modifierLists: [MenuItemModifierList]) -> [String]? {
        guard !modifierLists.isEmpty else { return nil }
        
        var customizations: [String] = []
        
        for modifierList in modifierLists {
            let name = modifierList.name.lowercased()
            
            if name.contains("size") {
                customizations.append("size")
            } else if name.contains("ice") {
                customizations.append("ice")
            } else if name.contains("milk") {
                customizations.append("milk")
            } else if name.contains("sugar") || name.contains("sweet") {
                customizations.append("sugar")
            } else {
                // For other modifier lists, use a generic type
                customizations.append("other")
            }
        }
        
        return customizations.isEmpty ? nil : customizations
    }
    
    private func fetchCloverOrder(orderId: String, credentials: CloverCredentials) async throws -> CloverOrderResponse {
        let baseURL = "https://api.clover.com/v3/merchants/\(credentials.merchantId)/orders/\(orderId)"
        
        guard let url = URL(string: baseURL) else {
            throw CloverAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloverAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(CloverErrorResponse.self, from: data) {
                    throw CloverAPIError.apiError(errorResponse.message)
                }
                throw CloverAPIError.httpError(httpResponse.statusCode)
            }
            
            let order = try JSONDecoder().decode(CloverOrderResponse.self, from: data)
            return order
            
        } catch {
            if error is CloverAPIError {
                throw error
            }
            throw CloverAPIError.networkError(error)
        }
    }
    
    private func convertCloverOrderToOrderStatus(_ cloverOrder: CloverOrderResponse) -> OrderStatus {
        // Map Clover order state to our OrderStatus
        switch cloverOrder.state?.lowercased() {
        case "open":
            return .submitted // Order is open and waiting for processing
        case "locked":
            return .inProgress // Order is locked and being prepared
        case "paid":
            // Check payment state for more specific status
            switch cloverOrder.paymentState?.uppercased() {
            case "PAID":
                return .completed // Order is fully paid
            case "PARTIALLY_PAID":
                return .inProgress // Still being processed
            case "REFUNDED", "PARTIALLY_REFUNDED":
                return .cancelled // Order was refunded
            default:
                return .ready // Default to ready if payment state is unclear
            }
        default:
            return .submitted // Default fallback
        }
    }
    
    private func fetchCloverBusinessHours(credentials: CloverCredentials) async throws -> [CloverOpeningHours] {
        // Use the correct opening_hours endpoint
        let baseURL = "https://sandbox.dev.clover.com/v3/merchants/\(credentials.merchantId)/opening_hours"
        
        guard let url = URL(string: baseURL) else {
            throw CloverAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CloverAPIError.invalidResponse
            }
            
            print("🔍 CloverAPIService: Business hours API response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // Log the actual response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ CloverAPIService: Business hours API error response: \(responseString)")
                }
                if let errorResponse = try? JSONDecoder().decode(CloverErrorResponse.self, from: data) {
                    let errorMessage = errorResponse.message
                    print("❌ CloverAPIService: Business hours API error: \(errorMessage)")
                    throw CloverAPIError.apiError(errorMessage)
                }
                print("❌ CloverAPIService: Business hours API HTTP error: \(httpResponse.statusCode)")
                throw CloverAPIError.httpError(httpResponse.statusCode)
            }
            
            // First, let's see what the opening_hours endpoint actually returns
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 CloverAPIService: Opening hours response: \(responseString)")
            }
            
            // Decode using the correct Clover opening hours structure
            do {
                let hoursResponse = try JSONDecoder().decode(CloverOpeningHoursResponse.self, from: data)
                let hours = hoursResponse.elements ?? []
                
                print("🔍 CloverAPIService: Found \(hours.count) opening hours entries")
                for hour in hours {
                    print("🔍 CloverAPIService: Opening hours entry - ID: \(hour.id), Name: \(hour.name ?? "N/A")")
                }
                
                return hours
            } catch {
                print("⚠️ CloverAPIService: Could not decode business hours from opening_hours endpoint")
                print("⚠️ CloverAPIService: Decode error: \(error)")
                return [] // Return empty array if parsing fails
            }
            
        } catch {
            if error is CloverAPIError {
                throw error
            }
            throw CloverAPIError.networkError(error)
        }
    }
    
    private func processCloverOpeningHours(_ cloverHours: [CloverOpeningHours]) -> BusinessHoursInfo {
        var weeklyHours: [String: [BusinessHoursPeriod]] = [:]
        
        // Process each opening hours entry (usually just one)
        for openingHours in cloverHours {
            print("🔍 CloverAPIService: Processing opening hours entry: \(openingHours.name ?? "N/A")")
            
            // Process each day of the week
            processCloverDay(openingHours.sunday, dayKey: "SUN", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.monday, dayKey: "MON", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.tuesday, dayKey: "TUE", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.wednesday, dayKey: "WED", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.thursday, dayKey: "THU", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.friday, dayKey: "FRI", weeklyHours: &weeklyHours)
            processCloverDay(openingHours.saturday, dayKey: "SAT", weeklyHours: &weeklyHours)
        }
        
        // Determine if currently open
        let isCurrentlyOpen = checkIfCurrentlyOpen(weeklyHours: weeklyHours)
        
        return BusinessHoursInfo(
            weeklyHours: weeklyHours,
            isCurrentlyOpen: isCurrentlyOpen
        )
    }
    
    private func processCloverDay(_ dayHours: CloverDayHours?, dayKey: String, weeklyHours: inout [String: [BusinessHoursPeriod]]) {
        guard let dayHours = dayHours, let timeSlots = dayHours.elements else {
            print("🔍 CloverAPIService: No hours for \(dayKey)")
            return
        }
        
        var periods: [BusinessHoursPeriod] = []
        
        for timeSlot in timeSlots {
            // Convert minutes since midnight to HH:mm format
            let startTime = convertMinutesToTimeString(timeSlot.start)
            let endTime = convertMinutesToTimeString(timeSlot.end)
            
            print("🔍 CloverAPIService: \(dayKey): \(startTime) - \(endTime)")
            
            let period = BusinessHoursPeriod(
                startTime: startTime,
                endTime: endTime
            )
            periods.append(period)
        }
        
        if !periods.isEmpty {
            weeklyHours[dayKey] = periods
        }
    }
    
    private func convertCloverDayToSquareFormat(_ cloverDay: String) -> String {
        switch cloverDay.uppercased() {
        case "MONDAY": return "MON"
        case "TUESDAY": return "TUE"
        case "WEDNESDAY": return "WED"
        case "THURSDAY": return "THU"
        case "FRIDAY": return "FRI"
        case "SATURDAY": return "SAT"
        case "SUNDAY": return "SUN"
        default: return "MON"
        }
    }
    
    private func convertMinutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        return String(format: "%02d:%02d", hours, mins)
    }
    
    private func checkIfCurrentlyOpen(weeklyHours: [String: [BusinessHoursPeriod]]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current day of week (1 = Sunday, 2 = Monday, etc.)
        let weekday = calendar.component(.weekday, from: now)
        
        // Convert to Square's day format (reusing Square's logic for consistency)
        let dayOfWeek = convertWeekdayToSquareFormat(weekday)
        
        guard let todayPeriods = weeklyHours[dayOfWeek] else {
            return false
        }
        
        // Get current time in HH:mm format
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: now)
        
        // Check if current time falls within any of today's periods
        for period in todayPeriods {
            if isTimeInRange(currentTime: currentTime, startTime: period.startTime, endTime: period.endTime) {
                return true
            }
        }
        
        return false
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
    
    private func isTimeInRange(currentTime: String, startTime: String, endTime: String) -> Bool {
        // Handle cases where business hours span midnight
        if startTime > endTime {
            // Business hours span midnight (e.g., 22:00 to 02:00)
            return currentTime >= startTime || currentTime <= endTime
        } else {
            // Normal business hours (e.g., 09:00 to 17:00)
            return currentTime >= startTime && currentTime <= endTime
        }
    }
}

// MARK: - Error Types

enum CloverAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }
}
