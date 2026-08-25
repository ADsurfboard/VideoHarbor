import Foundation

public enum YTDLPOutputError: LocalizedError {
    case invalidMetadata

    public var errorDescription: String? {
        "视频站点返回了无法识别的元数据。"
    }
}

public enum YTDLPOutputParser {
    public static func metadata(
        from data: Data,
        sourceURL: URL,
        fallbackPlatform: VideoPlatform
    ) throws -> VideoMetadata {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = string(object["id"]),
              let title = string(object["title"]) else {
            throw YTDLPOutputError.invalidMetadata
        }

        let resolvedURL = string(object["webpage_url"]).flatMap(URL.init(string:)) ?? sourceURL
        let thumbnail = string(object["thumbnail"]).flatMap(URL.init(string:))
        let platform = platform(from: object, fallback: fallbackPlatform)
        let requested = (object["requested_downloads"] as? [[String: Any]])?.first

        return VideoMetadata(
            id: id,
            title: title,
            uploader: string(object["uploader"]) ?? string(object["channel"]),
            duration: number(object["duration"]),
            thumbnailURL: thumbnail,
            webpageURL: resolvedURL,
            platform: platform,
            width: integer(object["width"]) ?? integer(requested?["width"]),
            height: integer(object["height"]) ?? integer(requested?["height"]),
            estimatedFileSize: int64(object["filesize_approx"])
                ?? int64(object["filesize"])
                ?? int64(requested?["filesize_approx"])
                ?? int64(requested?["filesize"])
        )
    }

    public static func progress(from line: String) -> DownloadProgress? {
        let prefix = "VH_PROGRESS:"
        guard line.hasPrefix(prefix),
              let data = String(line.dropFirst(prefix.count)).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let downloaded = int64(object["downloaded_bytes"])
        let total = int64(object["total_bytes"]) ?? int64(object["total_bytes_estimate"])
        let percent = number(object["_percent"])
            ?? string(object["_percent_str"]).flatMap(parsePercent)
        let fraction: Double
        if let percent {
            // yt-dlp reports `_percent` in 0...100 units, including tiny values
            // such as 0.0035. It is never a 0...1 fraction.
            fraction = max(0, min(1, percent / 100))
        } else if let downloaded, let total, total > 0 {
            fraction = max(0, min(1, Double(downloaded) / Double(total)))
        } else {
            fraction = 0
        }

        return DownloadProgress(
            fraction: fraction,
            downloadedBytes: downloaded,
            totalBytes: total,
            bytesPerSecond: number(object["speed"]),
            etaSeconds: number(object["eta"]),
            status: string(object["status"])
        )
    }

    public static func finalPath(from line: String) -> String? {
        let prefix = "VH_FILE:"
        guard line.hasPrefix(prefix) else { return nil }
        let value = String(line.dropFirst(prefix.count))
        return value.isEmpty ? nil : value
    }

    public static func friendlyError(from output: String) -> String {
        let lines = output.split(whereSeparator: { $0.isNewline }).map(String.init)
        let errorLine = lines.last { $0.localizedCaseInsensitiveContains("ERROR:") }
        let raw = errorLine ?? lines.suffix(4).joined(separator: "\n")
        if isCookieAccessFailure(output) {
            return "macOS 阻止了浏览器 Cookie 访问。请在设置中选择「不使用 Cookie」提取公开内容；登录内容可改用已授权的其他浏览器。"
        }
        if raw.localizedCaseInsensitiveContains("cookies") {
            return "站点要求登录或 Cookie 已失效。请在设置中选择已登录的浏览器后重试。"
        }
        if raw.localizedCaseInsensitiveContains("unsupported url") {
            return "该链接暂不受支持，请粘贴单个视频的完整分享链接。"
        }
        if raw.localizedCaseInsensitiveContains("requested format is not available") {
            return "平台没有返回符合当前清晰度的无水印源流。可尝试「最佳质量」或选择已登录的浏览器 Cookie。"
        }
        if raw.localizedCaseInsensitiveContains("private") || raw.localizedCaseInsensitiveContains("login") {
            return "该视频不是公开内容或需要登录。请确认你有权访问并选择已登录的浏览器。"
        }
        if raw.localizedCaseInsensitiveContains("drm") {
            return "该内容受 DRM 保护，VideoHarbor 不会绕过保护。"
        }
        return raw.isEmpty ? "提取失败，请检查网络和链接后重试。" : raw
    }

    public static func isCookieAccessFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        guard normalized.contains("cookie") else { return false }
        return normalized.contains("operation not permitted")
            || normalized.contains("permission denied")
            || normalized.contains("failed to load cookies")
            || normalized.contains("could not copy")
            || normalized.contains("cannot decrypt")
            || normalized.contains("could not decrypt")
            || normalized.contains("keyring")
    }

    public static func isFreshCookieFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("fresh cookies")
            && normalized.contains("needed")
    }

    private static func platform(
        from object: [String: Any],
        fallback: VideoPlatform
    ) -> VideoPlatform {
        let name = [string(object["extractor_key"]), string(object["extractor"])]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        if name.contains("douyin") { return .douyin }
        if name.contains("bilibili") { return .bilibili }
        if name.contains("youtube") { return .youtube }
        if name.contains("tiktok") { return .tiktok }
        return fallback
    }

    private static func parsePercent(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        number(value).map(Int.init)
    }

    private static func int64(_ value: Any?) -> Int64? {
        number(value).map(Int64.init)
    }
}
