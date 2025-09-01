import Foundation

// MARK: - POS Service Protocol

protocol POSServiceProtocol {
    /// Fetches menu data for a coffee shop
    func fetchMenuData(for shop: CoffeeShop) async throws -> [MenuCategory]
    
    /// Fetches business hours for a coffee shop
    func fetchBusinessHours(for shop: CoffeeShop) async throws -> BusinessHoursInfo?
    
    /// Fetches order status for a given order ID
    func fetchOrderStatus(orderId: String, merchantId: String) async throws -> OrderStatus
}

// MARK: - POS Service Factory

class POSServiceFactory {
    static func createService(for posType: POSType) -> POSServiceProtocol {
        switch posType {
        case .square:
            return SquareAPIService.shared
        case .clover:
            return CloverAPIService.shared
        }
    }
    
    static func createService(for shop: CoffeeShop) -> POSServiceProtocol {
        return createService(for: shop.posType)
    }
}

// MARK: - POS Service Extensions

extension SquareAPIService: POSServiceProtocol {
    // SquareAPIService already implements the required methods
}

// CloverAPIService will implement POSServiceProtocol in its own file
