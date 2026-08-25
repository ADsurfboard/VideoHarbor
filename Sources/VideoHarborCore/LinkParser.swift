import Foundation

public enum LinkParserError: LocalizedError, Equatable {
    case missingURL
    case unsupportedScheme
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .missingURL:
            return "没有在分享文本中找到视频链接。"
        case .unsupportedScheme:
            return "仅支持 HTTP 或 HTTPS 链接。"
        case .unsupportedPlatform:
            return "当前仅支持拖音、哔哩哔哩、YouTube 和 TikTok。"
        }
    }
}

public enum VideoLinkParser {
    private static let trailingPunctuation = CharacterSet(
        charactersIn: ".,;:!?)]}>。，；：！？、”’》】）」』"
    )

    public static func extractURL(from shareText: String) throws -> URL {
        let range = NSRange(shareText.startIndex..<shareText.endIndex, in: shareText)
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let match = detector.firstMatch(in: shareText, options: [], range: range),
              let matchRange = Range(match.range, in: shareText) else {
            throw LinkParserError.missingURL
        }

        var candidate = String(shareText[matchRange])
        candidate = candidate.trimmingCharacters(in: trailingPunctuation)
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw LinkParserError.unsupportedScheme
        }
        return url
    }

    public static func platform(for url: URL) -> VideoPlatform {
        guard let host = url.host?.lowercased() else { return .unknown }
        if matches(host, domains: ["douyin.com", "iesdouyin.com"]) {
            return .douyin
        }
        if matches(host, domains: ["bilibili.com", "b23.tv"]) {
            return .bilibili
        }
        if matches(host, domains: ["youtube.com", "youtu.be", "youtube-nocookie.com"]) {
            return .youtube
        }
        if matches(host, domains: ["tiktok.com"]) {
            return .tiktok
        }
        return .unknown
    }

    public static func parseSupportedURL(from shareText: String) throws -> (URL, VideoPlatform) {
        let url = try extractURL(from: shareText)
        let platform = platform(for: url)
        guard platform != .unknown else { throw LinkParserError.unsupportedPlatform }
        return (url, platform)
    }

    private static func matches(_ host: String, domains: [String]) -> Bool {
        domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
