import Foundation

/// Persistent cache for business hours that survives app launches.
actor BusinessHoursCache {
    struct CacheEntry: Codable {
        let info: BusinessHoursInfo
        let lastUpdated: Date
    }

    private struct CachePayload: Codable {
        let entries: [String: CacheEntry]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        fileManager: FileManager = .default,
        filename: String = "business_hours_cache.json"
    ) {
        self.fileManager = fileManager

        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            fileURL = cachesDirectory.appendingPathComponent(filename)
        } else {
            fileURL = fileManager.temporaryDirectory.appendingPathComponent(filename)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func load() -> [String: CacheEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try decoder.decode(CachePayload.self, from: data)
            return payload.entries
        } catch {
            print("❌ BusinessHoursCache: Failed to load cache: \(error)")
            return [:]
        }
    }

    func save(_ entries: [String: CacheEntry]) async {
        do {
            let payload = CachePayload(entries: entries)
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ BusinessHoursCache: Failed to save cache: \(error)")
        }
    }

    func clear() async {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("❌ BusinessHoursCache: Failed to clear cache: \(error)")
        }
    }
}
