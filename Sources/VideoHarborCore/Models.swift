import Foundation

public enum VideoPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case douyin
    case bilibili
    case youtube
    case tiktok
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .douyin: return "拖音"
        case .bilibili: return "哔哩哔哩"
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .unknown: return "未识别平台"
        }
    }

    public var symbolName: String {
        switch self {
        case .douyin: return "music.note.tv.fill"
        case .bilibili: return "play.rectangle.fill"
        case .youtube: return "play.square.fill"
        case .tiktok: return "music.note"
        case .unknown: return "link"
        }
    }
}

public enum DownloadQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case best
    case uhd2160
    case fullHD1080
    case hd720

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .best: return "最佳质量"
        case .uhd2160: return "4K / 2160p"
        case .fullHD1080: return "1080p"
        case .hd720: return "720p"
        }
    }

    public var maximumHeight: Int? {
        switch self {
        case .best: return nil
        case .uhd2160: return 2160
        case .fullHD1080: return 1080
        case .hd720: return 720
        }
    }
}

public enum MediaContainer: String, Codable, CaseIterable, Identifiable, Sendable {
    case mp4
    case mkv

    public var id: String { rawValue }
    public var displayName: String { rawValue.uppercased() }
}

public enum CookieBrowser: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case safari
    case chrome
    case firefox
    case edge
    case brave

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "不使用 Cookie"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox"
        case .edge: return "Microsoft Edge"
        case .brave: return "Brave"
        }
    }
}

public enum HarborAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case dark
    case light
    case ultraClear

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dark: return "深色"
        case .light: return "浅色"
        case .ultraClear: return "满血透明"
        }
    }
}

public enum WallpaperKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case harbor
    case image
    case video

    public var id: String { rawValue }
}

public struct WallpaperSettings: Codable, Equatable, Sendable {
    public var kind: WallpaperKind
    public var filePath: String?
    public var transparency: Double
    public var dimming: Double
    public var blur: Double
    public var backdropBlur: Double

    public init(
        kind: WallpaperKind = .harbor,
        filePath: String? = nil,
        transparency: Double = 0.18,
        dimming: Double = 0.08,
        blur: Double = 0,
        backdropBlur: Double = 24
    ) {
        self.kind = kind
        self.filePath = filePath
        self.transparency = transparency
        self.dimming = dimming
        self.blur = blur
        self.backdropBlur = backdropBlur
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var outputDirectory: String
    public var quality: DownloadQuality
    public var container: MediaContainer
    public var cookieBrowser: CookieBrowser
    public var appearance: HarborAppearance
    public var wallpaper: WallpaperSettings
    public var pauseBackgroundWhenInactive: Bool

    public init(
        outputDirectory: String = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first?.path ?? NSHomeDirectory() + "/Downloads",
        quality: DownloadQuality = .best,
        container: MediaContainer = .mp4,
        cookieBrowser: CookieBrowser = .none,
        appearance: HarborAppearance = .ultraClear,
        wallpaper: WallpaperSettings = WallpaperSettings(),
        pauseBackgroundWhenInactive: Bool = true
    ) {
        self.outputDirectory = outputDirectory
        self.quality = quality
        self.container = container
        self.cookieBrowser = cookieBrowser
        self.appearance = appearance
        self.wallpaper = wallpaper
        self.pauseBackgroundWhenInactive = pauseBackgroundWhenInactive
    }
}

public struct VideoMetadata: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let uploader: String?
    public let duration: Double?
    public let thumbnailURL: URL?
    public let webpageURL: URL
    public let platform: VideoPlatform
    public let width: Int?
    public let height: Int?
    public let estimatedFileSize: Int64?

    public init(
        id: String,
        title: String,
        uploader: String?,
        duration: Double?,
        thumbnailURL: URL?,
        webpageURL: URL,
        platform: VideoPlatform,
        width: Int?,
        height: Int?,
        estimatedFileSize: Int64?
    ) {
        self.id = id
        self.title = title
        self.uploader = uploader
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.webpageURL = webpageURL
        self.platform = platform
        self.width = width
        self.height = height
        self.estimatedFileSize = estimatedFileSize
    }
}

public enum DownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case processing
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

public struct DownloadRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public let sourceURL: URL
    public let title: String
    public let platform: VideoPlatform
    public var status: DownloadStatus
    public var progress: Double
    public var downloadedBytes: Int64?
    public var totalBytes: Int64?
    public var bytesPerSecond: Double?
    public var etaSeconds: Double?
    public var outputPath: String?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceURL: URL,
        title: String,
        platform: VideoPlatform,
        status: DownloadStatus = .queued,
        progress: Double = 0,
        downloadedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        bytesPerSecond: Double? = nil,
        etaSeconds: Double? = nil,
        outputPath: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceURL = sourceURL
        self.title = title
        self.platform = platform
        self.status = status
        self.progress = progress
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.bytesPerSecond = bytesPerSecond
        self.etaSeconds = etaSeconds
        self.outputPath = outputPath
        self.errorMessage = errorMessage
    }
}

public struct DownloadProgress: Equatable, Sendable {
    public let fraction: Double
    public let downloadedBytes: Int64?
    public let totalBytes: Int64?
    public let bytesPerSecond: Double?
    public let etaSeconds: Double?
    public let status: String?
}

public struct ToolchainPaths: Equatable, Sendable {
    public var ytDLP: URL
    public var ffmpegDirectory: URL?
    public var javaScriptRuntime: URL?
    public var javaScriptRuntimeName: String

    public init(
        ytDLP: URL,
        ffmpegDirectory: URL? = nil,
        javaScriptRuntime: URL? = nil,
        javaScriptRuntimeName: String = "node"
    ) {
        self.ytDLP = ytDLP
        self.ffmpegDirectory = ffmpegDirectory
        self.javaScriptRuntime = javaScriptRuntime
        self.javaScriptRuntimeName = javaScriptRuntimeName
    }
}
