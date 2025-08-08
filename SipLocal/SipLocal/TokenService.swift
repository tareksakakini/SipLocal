import Foundation

class TokenService {
    private let baseURL = "https://us-central1-coffee-55670.cloudfunctions.net"
    private static var memoryCache: [String: SquareCredentials] = [:]
    private static var cacheTimestamps: [String: TimeInterval] = [:]
    private let cacheTTL: TimeInterval = 60 * 30 // 30 minutes
    
    func getMerchantTokens(merchantId: String) async throws -> SquareCredentials {
        print("🔐 TokenService: Fetching tokens for merchantId: \(merchantId)")
        // Serve from in-memory cache if fresh
        if let creds = Self.memoryCache[merchantId], let ts = Self.cacheTimestamps[merchantId] {
            if Date().timeIntervalSince1970 - ts < cacheTTL {
                return creds
            }
        }
        
        guard let url = URL(string: "\(baseURL)/getMerchantTokens") else {
            throw TokenServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["merchantId": merchantId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🔐 TokenService: Making HTTP request to Firebase function")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ TokenService: Invalid response type")
                throw TokenServiceError.invalidResponse
            }
            
            print("🔐 TokenService: Received HTTP response with status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ TokenService: HTTP error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TokenService: Error response: \(errorString)")
                }
                throw TokenServiceError.httpError(httpResponse.statusCode)
            }
            
            guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ TokenService: Invalid JSON response format")
                throw TokenServiceError.invalidResponse
            }
            
            print("🔐 TokenService: Response data keys: \(responseDict.keys)")
            
            guard let tokens = responseDict["tokens"] as? [String: Any] else {
                print("❌ TokenService: No 'tokens' key found in response")
                throw TokenServiceError.invalidResponse
            }
            
            print("🔐 TokenService: Token data keys: \(tokens.keys)")
            
            guard let oauthToken = tokens["oauth_token"] as? String,
                  let merchantIdFromTokens = tokens["merchantId"] as? String,
                  let refreshToken = tokens["refreshToken"] as? String else {
                print("❌ TokenService: Missing required token fields")
                print("  oauth_token: \(tokens["oauth_token"] != nil)")
                print("  merchantId: \(tokens["merchantId"] != nil)")  
                print("  refreshToken: \(tokens["refreshToken"] != nil)")
                throw TokenServiceError.invalidResponse
            }
            
            print("✅ TokenService: Successfully parsed tokens for merchant: \(merchantIdFromTokens)")
            
            let creds = SquareCredentials(
                oauth_token: oauthToken,
                merchantId: merchantIdFromTokens,
                refreshToken: refreshToken
            )
            // cache
            Self.memoryCache[merchantId] = creds
            Self.cacheTimestamps[merchantId] = Date().timeIntervalSince1970
            return creds
        } catch {
            print("❌ TokenService: Error fetching merchant tokens: \(error)")
            if let nsError = error as NSError? {
                print("❌ TokenService: Error domain: \(nsError.domain)")
                print("❌ TokenService: Error code: \(nsError.code)")
                print("❌ TokenService: Error userInfo: \(nsError.userInfo)")
            }
            throw TokenServiceError.networkError(error)
        }
    }
}

enum TokenServiceError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}