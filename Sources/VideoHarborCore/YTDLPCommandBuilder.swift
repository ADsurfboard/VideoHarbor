import Foundation

public struct DownloadOptions: Equatable, Sendable {
    public var outputDirectory: URL
    public var quality: DownloadQuality
    public var container: MediaContainer
    public var cookieBrowser: CookieBrowser

    public init(
        outputDirectory: URL,
        quality: DownloadQuality,
        container: MediaContainer,
        cookieBrowser: CookieBrowser
    ) {
        self.outputDirectory = outputDirectory
        self.quality = quality
        self.container = container
        self.cookieBrowser = cookieBrowser
    }
}

public enum YTDLPCommandBuilder {
    public static func metadataArguments(
        url: URL,
        cookieBrowser: CookieBrowser,
        toolchain: ToolchainPaths
    ) -> [String] {
        var arguments = commonArguments(cookieBrowser: cookieBrowser, toolchain: toolchain)
        arguments += [
            "--dump-single-json",
            "--skip-download",
            "--no-warnings",
            "--",
            url.absoluteString
        ]
        return arguments
    }

    public static func downloadArguments(
        url: URL,
        options: DownloadOptions,
        toolchain: ToolchainPaths
    ) -> [String] {
        var arguments = commonArguments(cookieBrowser: options.cookieBrowser, toolchain: toolchain)
        arguments += [
            "--newline",
            "--progress",
            "--progress-template", "download:VH_PROGRESS:%(progress)j",
            "--print", "after_move:VH_FILE:%(filepath)s",
            "--paths", "home:\(options.outputDirectory.path)",
            "--output", "%(title).180B [%(id)s].%(ext)s",
            "--windows-filenames",
            "--trim-filenames", "220",
            "--format", formatSelector(for: options.quality),
            "--merge-output-format", options.container.rawValue,
            "--embed-metadata",
            "--no-overwrites",
            "--",
            url.absoluteString
        ]
        return arguments
    }

    private static func commonArguments(
        cookieBrowser: CookieBrowser,
        toolchain: ToolchainPaths
    ) -> [String] {
        var arguments = [
            "--ignore-config",
            "--no-playlist",
            "--no-color"
        ]
        if let ffmpegDirectory = toolchain.ffmpegDirectory {
            arguments += ["--ffmpeg-location", ffmpegDirectory.path]
        }
        if let runtime = toolchain.javaScriptRuntime {
            arguments += [
                "--js-runtimes",
                "\(toolchain.javaScriptRuntimeName):\(runtime.path)"
            ]
        }
        if cookieBrowser != .none {
            arguments += ["--cookies-from-browser", cookieBrowser.rawValue]
        }
        return arguments
    }

    private static func formatSelector(for quality: DownloadQuality) -> String {
        // `?` keeps formats whose note is absent while still rejecting an
        // explicit `watermarked` label from TikTok/Douyin extractors.
        let clean = "format_note!*=?watermarked"
        guard let height = quality.maximumHeight else {
            return "bestvideo*[\(clean)]+bestaudio/best[\(clean)]"
        }
        return "bestvideo*[height<=?\(height)][\(clean)]+bestaudio/best[height<=?\(height)][\(clean)]"
    }
}
