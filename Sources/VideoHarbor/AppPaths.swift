import Foundation

struct AppPaths {
    let root: URL
    let settings: URL
    let history: URL
    let wallpapers: URL

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        root = support.appendingPathComponent("VideoHarbor", isDirectory: true)
        settings = root.appendingPathComponent("settings.json")
        history = root.appendingPathComponent("history.json")
        wallpapers = root.appendingPathComponent("Wallpapers", isDirectory: true)
    }

    func prepare(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wallpapers, withIntermediateDirectories: true)
    }
}

enum JSONStore {
    static func load<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.videoHarbor.decode(type, from: data)
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL) {
        guard let data = try? JSONEncoder.videoHarbor.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static var videoHarbor: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var videoHarbor: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
