import Foundation

/// File name constants for JSON persistence.
enum StoreFile {
    static let medicines  = "medicines"
    static let schedules  = "schedules"
    static let doseLogs   = "dose_logs"
    static let settings   = "settings"
}

/// Actor-based JSON persistence. All file I/O is serialized to prevent data races.
actor JSONStore {
    static let shared = JSONStore()

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    // MARK: - File Paths

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func jsonFileURL(for filename: String) -> URL {
        documentsURL.appendingPathComponent("\(filename).json")
    }

    // MARK: - CRUD Operations

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: jsonFileURL(for: filename), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let data = try Data(contentsOf: jsonFileURL(for: filename))
        return try decoder.decode(type, from: data)
    }

    func loadOrDefault<T: Decodable>(_ type: T.Type, from filename: String, default fallback: T) -> T {
        (try? load(type, from: filename)) ?? fallback
    }

    func delete(filename: String) throws {
        let url = jsonFileURL(for: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func exists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: jsonFileURL(for: filename).path)
    }
}
