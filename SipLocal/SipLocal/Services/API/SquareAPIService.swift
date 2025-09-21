import Foundation

final class SquareAPIService {
    static let shared = SquareAPIService()

    private let tokenService: TokenService
    private let apiClient: SquareAPIClient
    private let catalogBuilder: SquareCatalogBuilder
    private let orderStatusMapper: SquareOrderStatusMapper
    private let businessHoursInterpreter: SquareBusinessHoursInterpreter
    private let requestEncoder: JSONEncoder

    init(
        tokenService: TokenService = TokenService(),
        apiClient: SquareAPIClient = SquareAPIClient(),
        catalogBuilder: SquareCatalogBuilder = SquareCatalogBuilder(),
        orderStatusMapper: SquareOrderStatusMapper = SquareOrderStatusMapper(),
        businessHoursInterpreter: SquareBusinessHoursInterpreter = SquareBusinessHoursInterpreter(),
        requestEncoder: JSONEncoder = SquareAPIService.makeRequestEncoder()
    ) {
        self.tokenService = tokenService
        self.apiClient = apiClient
        self.catalogBuilder = catalogBuilder
        self.orderStatusMapper = orderStatusMapper
        self.businessHoursInterpreter = businessHoursInterpreter
        self.requestEncoder = requestEncoder
    }

    // MARK: - Menu Fetching

    func fetchMenuData(for shop: CoffeeShop) async throws -> [MenuCategory] {
        print("🔍 SquareAPIService: Starting menu fetch for shop: \(shop.name) (merchantId: \(shop.merchantId))")

        do {
            print("🔍 SquareAPIService: Fetching tokens from backend...")
            let credentials = try await tokenService.getMerchantTokens(merchantId: shop.merchantId)
            print("🔍 SquareAPIService: Successfully got credentials, fetching catalog...")

            let catalogObjects = try await fetchCatalogObjects(credentials: credentials)
            print("🔍 SquareAPIService: Successfully fetched \(catalogObjects.count) catalog objects")

            let categories = catalogBuilder.buildMenuCategories(from: catalogObjects)
            print("🔍 SquareAPIService: Successfully processed into \(categories.count) menu categories")

            return categories
        } catch {
            print("❌ SquareAPIService: Error fetching menu data for \(shop.name): \(error)")
            print("❌ SquareAPIService: Error type: \(type(of: error))")
            print("❌ SquareAPIService: Error description: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Order Status Fetching

    func fetchOrderStatus(orderId: String, merchantId: String) async throws -> OrderStatus {
        do {
            let credentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
            let squareOrder = try await fetchSquareOrder(orderId: orderId, credentials: credentials)
            return orderStatusMapper.map(squareOrder: squareOrder)
        } catch {
            print("❌ SquareAPIService: Error fetching order status: \(error)")
            throw error
        }
    }

    // MARK: - Business Hours Fetching

    func fetchBusinessHours(for shop: CoffeeShop) async throws -> BusinessHoursInfo? {
        print("🔍 SquareAPIService: Starting business hours fetch for shop: \(shop.name) (merchantId: \(shop.merchantId))")

        do {
            let credentials = try await tokenService.getMerchantTokens(merchantId: shop.merchantId)

            print("🔍 SquareAPIService: Fetching locations from Square API...")
            let locations = try await fetchLocations(credentials: credentials)
            print("🔍 SquareAPIService: Found \(locations.count) locations for \(shop.name)")

            guard let firstLocation = locations.first else {
                print("❌ SquareAPIService: No locations found for \(shop.name)")
                return nil
            }

            print("🔍 SquareAPIService: Using location: \(firstLocation.id) - \(firstLocation.name ?? "Unnamed")")

            let location = try await fetchLocationDetails(locationId: firstLocation.id, credentials: credentials)

            guard let businessHours = location.businessHours else {
                print("🔍 SquareAPIService: No business hours found for \(shop.name)")
                return nil
            }

            let businessHoursInfo = businessHoursInterpreter.makeBusinessHoursInfo(from: businessHours)
            print("🔍 SquareAPIService: Successfully processed business hours for \(shop.name)")

            return businessHoursInfo
        } catch {
            print("❌ SquareAPIService: Error fetching business hours for \(shop.name): \(error)")
            throw error
        }
    }
}

// MARK: - Private Helpers

private extension SquareAPIService {
    struct SquareCatalogSearchRequest: Encodable {
        let objectTypes: [String]
        let includeRelatedObjects: Bool
    }

    static func makeRequestEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    func fetchCatalogObjects(credentials: SquareCredentials) async throws -> [SquareCatalogObject] {
        let requestBody = SquareCatalogSearchRequest(
            objectTypes: ["ITEM", "CATEGORY", "IMAGE", "MODIFIER_LIST"],
            includeRelatedObjects: true
        )

        let body = try requestEncoder.encode(requestBody)
        let descriptor = SquareRequestDescriptor(
            path: "catalog/search",
            method: .post,
            body: body
        )

        let response: SquareCatalogSearchResponse = try await apiClient.send(
            descriptor,
            credentials: credentials
        )

        return response.combinedObjects
    }

    func fetchSquareOrder(orderId: String, credentials: SquareCredentials) async throws -> SquareOrder {
        let descriptor = SquareRequestDescriptor(path: "orders/\(orderId)")
        let response: SquareOrderResponse = try await apiClient.send(descriptor, credentials: credentials)

        guard let order = response.order else {
            throw SquareAPIError.apiError("Order not found")
        }

        return order
    }

    func fetchLocationDetails(locationId: String, credentials: SquareCredentials) async throws -> SquareLocation {
        let descriptor = SquareRequestDescriptor(path: "locations/\(locationId)")
        let response: SquareLocationResponse = try await apiClient.send(descriptor, credentials: credentials)

        guard let location = response.location else {
            throw SquareAPIError.apiError("Location not found")
        }

        print("🔍 SquareAPIService: Location details - ID: \(location.id), Name: \(location.name ?? "Unnamed")")
        if let businessHours = location.businessHours {
            print("🔍 SquareAPIService: Business hours found - Periods: \(businessHours.periods?.count ?? 0)")
            if let periods = businessHours.periods {
                for period in periods {
                    print("🔍 SquareAPIService: Period - Day: \(period.dayOfWeek), Start: \(period.startLocalTime ?? "N/A"), End: \(period.endLocalTime ?? "N/A")")
                }
            }
        } else {
            print("🔍 SquareAPIService: No business hours found for this location")
        }

        return location
    }

    func fetchLocations(credentials: SquareCredentials) async throws -> [SquareLocation] {
        let descriptor = SquareRequestDescriptor(path: "locations")
        let response: SquareLocationsResponse = try await apiClient.send(descriptor, credentials: credentials)

        let locations = response.locations ?? []
        print("🔍 SquareAPIService: Found \(locations.count) locations")
        for location in locations {
            print("🔍 SquareAPIService: Location - ID: \(location.id), Name: \(location.name ?? "Unnamed"), Has Business Hours: \(location.businessHours != nil)")
        }

        return locations
    }
}

private extension SquareCatalogSearchResponse {
    var combinedObjects: [SquareCatalogObject] {
        var objects = self.objects ?? []
        if let related = relatedObjects {
            objects.append(contentsOf: related)
        }
        return objects
    }
}

// MARK: - Catalog Builder

struct SquareCatalogBuilder {
    func buildMenuCategories(from objects: [SquareCatalogObject]) -> [MenuCategory] {
        let context = CatalogContext(objects: objects)
        var processedItemIds: Set<String> = []
        var menuCategories: [MenuCategory] = []

        for categoryObject in context.categories {
            guard let categoryData = categoryObject.categoryData else { continue }

            let categoryItems = context.items.compactMap { itemObject -> MenuItem? in
                guard context.itemBelongsToCategory(itemObject, categoryId: categoryObject.id) else { return nil }
                processedItemIds.insert(itemObject.id)
                return context.makeMenuItem(from: itemObject)
            }

            if !categoryItems.isEmpty {
                menuCategories.append(MenuCategory(name: categoryData.name, items: categoryItems))
            }
        }

        let remainingItems = context.items.compactMap { itemObject -> MenuItem? in
            guard !processedItemIds.contains(itemObject.id) else { return nil }
            return context.makeMenuItem(from: itemObject)
        }

        if !remainingItems.isEmpty {
            menuCategories.append(MenuCategory(name: "Other", items: remainingItems))
        }

        return menuCategories.sorted { $0.name < $1.name }
    }
}

private extension SquareCatalogBuilder {
    struct CatalogContext {
        let categories: [SquareCatalogObject]
        let items: [SquareCatalogObject]

        private let imageMapping: [String: String]
        private let modifierListMapping: [String: MenuItemModifierList]

        init(objects: [SquareCatalogObject]) {
            categories = objects.filter { $0.type == "CATEGORY" }
            items = objects.filter { $0.type == "ITEM" }

            let images = objects.filter { $0.type == "IMAGE" }
            imageMapping = CatalogContext.makeImageMapping(from: images)

            let modifierLists = objects.filter { $0.type == "MODIFIER_LIST" }
            modifierListMapping = CatalogContext.makeModifierListMapping(from: modifierLists)
        }

        func itemBelongsToCategory(_ itemObject: SquareCatalogObject, categoryId: String) -> Bool {
            guard let itemData = itemObject.itemData else { return false }
            let itemCategoryIds = itemData.categories?.map { $0.id } ?? []
            return itemCategoryIds.contains(categoryId)
        }

        func makeMenuItem(from itemObject: SquareCatalogObject) -> MenuItem? {
            guard let itemData = itemObject.itemData else { return nil }

            let variations = CatalogContext.makeItemVariations(itemData.variations)
            let basePrice = variations.first?.price ?? 0.0
            let modifierLists = modifierLists(for: itemData)
            let imageURL = imageURL(for: itemData)
            let customizations = CatalogContext.extractCustomizationTypes(from: modifierLists)

            return MenuItem(
                id: itemObject.id,
                name: itemData.name,
                price: basePrice,
                variations: variations.isEmpty ? nil : variations,
                customizations: customizations,
                imageURL: imageURL,
                modifierLists: modifierLists
            )
        }

        private func modifierLists(for itemData: SquareItemData) -> [MenuItemModifierList] {
            guard let modifierInfos = itemData.modifierListInfo else { return [] }

            return modifierInfos.compactMap { info -> MenuItemModifierList? in
                if info.enabled == false || info.hiddenFromCustomer == true {
                    return nil
                }

                guard let baseList = modifierListMapping[info.modifierListId] else { return nil }

                let minSelections = max(0, info.minSelectedModifiers ?? 0)
                let maxSelections = info.maxSelectedModifiers ?? 1

                return MenuItemModifierList(
                    id: baseList.id,
                    name: baseList.name,
                    selectionType: baseList.selectionType,
                    minSelections: minSelections,
                    maxSelections: maxSelections,
                    modifiers: baseList.modifiers
                )
            }
        }

        private func imageURL(for itemData: SquareItemData) -> String? {
            guard let firstImageId = itemData.imageIds?.first else {
                print("DEBUG: No imageIds found for item '\(itemData.name)'")
                return nil
            }

            let imageURL = imageMapping[firstImageId]
            print("DEBUG: Item '\(itemData.name)' -> imageId: \(firstImageId) -> URL: \(imageURL ?? "nil")")
            return imageURL
        }

        static func makeImageMapping(from images: [SquareCatalogObject]) -> [String: String] {
            var mapping: [String: String] = [:]

            for imageObject in images {
                guard let imageData = imageObject.imageData,
                      let imageURL = imageData.url else { continue }

                mapping[imageObject.id] = imageURL
            }

            print("DEBUG: Created image mapping with \(mapping.count) images")
            return mapping
        }

        static func makeModifierListMapping(from modifierLists: [SquareCatalogObject]) -> [String: MenuItemModifierList] {
            var mapping: [String: MenuItemModifierList] = [:]

            for modifierListObject in modifierLists {
                guard let modifierListData = modifierListObject.modifierListData else { continue }

                let appModifiers = modifierListData.modifiers?.compactMap { squareModifier -> MenuItemModifier? in
                    guard let modifierData = squareModifier.modifierData else { return nil }

                    let priceInCents = modifierData.priceMoney?.amount ?? 0
                    let price = Double(priceInCents) / 100.0

                    return MenuItemModifier(
                        id: squareModifier.id,
                        name: modifierData.name,
                        price: price,
                        isDefault: modifierData.onByDefault ?? false
                    )
                } ?? []

                let appModifierList = MenuItemModifierList(
                    id: modifierListObject.id,
                    name: modifierListData.name,
                    selectionType: modifierListData.selectionType ?? "SINGLE",
                    minSelections: 0,
                    maxSelections: 1,
                    modifiers: appModifiers
                )

                mapping[modifierListObject.id] = appModifierList
            }

            print("DEBUG: Created modifier list mapping with \(mapping.count) modifier lists")
            return mapping
        }

        static func makeItemVariations(_ squareVariations: [SquareItemVariation]?) -> [MenuItemVariation] {
            guard let squareVariations = squareVariations else { return [] }

            let variations = squareVariations.compactMap { variation -> MenuItemVariation? in
                guard let variationData = variation.itemVariationData else { return nil }

                let priceInCents = variationData.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0

                return MenuItemVariation(
                    id: variation.id,
                    name: variationData.name ?? "Size",
                    price: price,
                    ordinal: variationData.ordinal ?? 0
                )
            }

            return variations.sorted { $0.ordinal < $1.ordinal }
        }

        static func extractCustomizationTypes(from modifierLists: [MenuItemModifierList]) -> [String]? {
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
                    customizations.append("other")
                }
            }

            return customizations.isEmpty ? nil : customizations
        }
    }
}

// MARK: - Order Status Mapper

struct SquareOrderStatusMapper {
    func map(squareOrder: SquareOrder) -> OrderStatus {
        let baseStatus = map(squareState: squareOrder.state)

        if baseStatus == .inProgress, let fulfillments = squareOrder.fulfillments {
            for fulfillment in fulfillments where fulfillment.type == "PICKUP" {
                switch fulfillment.state.uppercased() {
                case "PROPOSED":
                    return .submitted
                case "RESERVED":
                    return .inProgress
                case "PREPARED":
                    return .ready
                case "FULFILLED":
                    return .completed
                case "CANCELED":
                    return .cancelled
                default:
                    return .inProgress
                }
            }
        }

        return baseStatus
    }

    private func map(squareState: String) -> OrderStatus {
        switch squareState.uppercased() {
        case "OPEN":
            return .inProgress
        case "COMPLETED":
            return .completed
        case "CANCELED":
            return .cancelled
        case "DRAFT":
            return .draft
        case "PENDING":
            return .pending
        default:
            return .submitted
        }
    }
}

// MARK: - Business Hours Interpreter

struct SquareBusinessHoursInterpreter {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func makeBusinessHoursInfo(from businessHours: SquareBusinessHours) -> BusinessHoursInfo {
        var weeklyHours: [String: [BusinessHoursPeriod]] = [:]

        if let periods = businessHours.periods {
            for period in periods {
                let periodInfo = BusinessHoursPeriod(
                    startTime: period.startLocalTime ?? "",
                    endTime: period.endLocalTime ?? ""
                )
                weeklyHours[period.dayOfWeek, default: []].append(periodInfo)
            }
        }

        let isCurrentlyOpen = checkIfCurrentlyOpen(weeklyHours: weeklyHours)

        return BusinessHoursInfo(
            weeklyHours: weeklyHours,
            isCurrentlyOpen: isCurrentlyOpen
        )
    }

    private func checkIfCurrentlyOpen(weeklyHours: [String: [BusinessHoursPeriod]]) -> Bool {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let dayOfWeek = convertWeekdayToSquareFormat(weekday)

        guard let todayPeriods = weeklyHours[dayOfWeek] else {
            return false
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: now)

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
        if startTime > endTime {
            return currentTime >= startTime || currentTime <= endTime
        } else {
            return currentTime >= startTime && currentTime <= endTime
        }
    }
}

// MARK: - Error Types

enum SquareAPIError: Error, LocalizedError {
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
