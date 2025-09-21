import Foundation

struct SquareRequestDescriptor {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Data?
    let additionalHeaders: [String: String]

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.additionalHeaders = additionalHeaders
    }

    func makeURLRequest(baseURL: URL, credentials: SquareCredentials) throws -> URLRequest {
        let endpointURL = baseURL.appendingPathComponent(path)

        guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) else {
            throw SquareAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let finalURL = components.url else {
            throw SquareAPIError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("Bearer \(credentials.oauth_token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}

final class SquareAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        baseURL: URL = URL(string: "https://connect.squareup.com/v2")!
    ) {
        self.session = session
        self.decoder = decoder
        self.baseURL = baseURL
    }

    func send<T: Decodable>(
        _ descriptor: SquareRequestDescriptor,
        credentials: SquareCredentials,
        responseType: T.Type = T.self
    ) async throws -> T {
        do {
            let request = try descriptor.makeURLRequest(baseURL: baseURL, credentials: credentials)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SquareAPIError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if let errorResponse = try? decoder.decode(SquareErrorResponse.self, from: data) {
                    let message = errorResponse.errors?.first?.detail ?? "Unknown error"
                    throw SquareAPIError.apiError(message)
                }
                throw SquareAPIError.httpError(httpResponse.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        } catch {
            if let squareError = error as? SquareAPIError {
                throw squareError
            }
            throw SquareAPIError.networkError(error)
        }
    }
}
