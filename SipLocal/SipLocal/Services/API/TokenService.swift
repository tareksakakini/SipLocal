import Foundation

class TokenService {
    private let baseURL = "https://us-central1-coffee-55670.cloudfunctions.net"
    private static var squareMemoryCache: [String: SquareCredentials] = [:]
    private static var squareCacheTimestamps: [String: TimeInterval] = [:]
    private static var cloverMemoryCache: [String: CloverCredentials] = [:]
    private static var cloverCacheTimestamps: [String: TimeInterval] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.siplocal.tokenservice.cache", attributes: .concurrent)
    private let cacheTTL: TimeInterval = 60 * 30 // 30 minutes
    
    func getMerchantTokens(merchantId: String) async throws -> SquareCredentials {
        print("🔐 TokenService: Fetching Square tokens for merchantId: \(merchantId)")
        
        // Check cache safely using concurrent queue
        let cachedCredentials: SquareCredentials? = Self.cacheQueue.sync {
            guard let creds = Self.squareMemoryCache[merchantId], 
                  let ts = Self.squareCacheTimestamps[merchantId] else {
                return nil
            }
            
            if Date().timeIntervalSince1970 - ts < cacheTTL {
                return creds
            } else {
                // Remove expired cache entry
                Self.squareMemoryCache.removeValue(forKey: merchantId)
                Self.squareCacheTimestamps.removeValue(forKey: merchantId)
                return nil
            }
        }
        
        if let cachedCredentials = cachedCredentials {
            print("🔐 TokenService: Returning cached Square credentials for merchantId: \(merchantId)")
            return cachedCredentials
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
            
            // Cache safely using barrier to ensure exclusive write access
            Self.cacheQueue.async(flags: .barrier) {
                Self.squareMemoryCache[merchantId] = creds
                Self.squareCacheTimestamps[merchantId] = Date().timeIntervalSince1970
            }
            
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
    
    func getCloverCredentials(merchantId: String) async throws -> CloverCredentials {
        print("🔐 TokenService: Fetching Clover tokens for merchantId: \(merchantId)")
        
        // Check cache safely using concurrent queue
        let cachedCredentials: CloverCredentials? = Self.cacheQueue.sync {
            guard let creds = Self.cloverMemoryCache[merchantId], 
                  let ts = Self.cloverCacheTimestamps[merchantId] else {
                return nil
            }
            
            if Date().timeIntervalSince1970 - ts < cacheTTL {
                return creds
            } else {
                // Remove expired cache entry
                Self.cloverMemoryCache.removeValue(forKey: merchantId)
                Self.cloverCacheTimestamps.removeValue(forKey: merchantId)
                return nil
            }
        }
        
        if let cachedCredentials = cachedCredentials {
            print("🔐 TokenService: Returning cached Clover credentials for merchantId: \(merchantId)")
            return cachedCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/getCloverCredentials") else {
            throw TokenServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["merchantId": merchantId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("🔐 TokenService: Making HTTP request to Firebase function for Clover credentials")
            
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
            
            guard let credentials = responseDict["credentials"] as? [String: Any] else {
                print("❌ TokenService: No 'credentials' key found in response")
                throw TokenServiceError.invalidResponse
            }
            
            print("🔐 TokenService: Credential data keys: \(credentials.keys)")
            
            guard let accessToken = credentials["accessToken"] as? String,
                  let merchantIdFromCredentials = credentials["merchantId"] as? String else {
                print("❌ TokenService: Missing required Clover credential fields")
                print("  accessToken: \(credentials["accessToken"] != nil)")
                print("  merchantId: \(credentials["merchantId"] != nil)")
                throw TokenServiceError.invalidResponse
            }
            
            print("✅ TokenService: Successfully parsed Clover credentials for merchant: \(merchantIdFromCredentials)")
            
            let creds = CloverCredentials(
                accessToken: accessToken,
                merchantId: merchantIdFromCredentials
            )
            
            // Cache safely using barrier to ensure exclusive write access
            Self.cacheQueue.async(flags: .barrier) {
                Self.cloverMemoryCache[merchantId] = creds
                Self.cloverCacheTimestamps[merchantId] = Date().timeIntervalSince1970
            }
            
            return creds
        } catch {
            print("❌ TokenService: Error fetching Clover credentials: \(error)")
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