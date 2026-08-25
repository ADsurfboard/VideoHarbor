import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

@main
enum StandaloneTests {
    static func main() throws {
        try testShareText()
        try testPlatforms()
        try testLookalikeDomains()
        try testCommand()
        try testProgress()
        try testMetadata()
        try testCookieAccessFailure()
        try testFreshCookieFailure()
        print("VideoHarborCore: 8/8 tests passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() { throw TestFailure(description: message) }
    }

    private static func requiredURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw TestFailure(description: "Invalid test URL: \(string)")
        }
        return url
    }

    private static func testShareText() throws {
        let input = "3.21 复制打开抖音 https://v.douyin.com/AbCdEf/ 长按复制。"
        let result = try VideoLinkParser.parseSupportedURL(from: input)
        try expect(result.0.absoluteString == "https://v.douyin.com/AbCdEf/", "Share URL extraction")
        try expect(result.1 == .douyin, "Share platform")
    }

    private static func testPlatforms() throws {
        let cases: [(String, VideoPlatform)] = [
            ("https://www.bilibili.com/video/BV123", .bilibili),
            ("https://b23.tv/abcd", .bilibili),
            ("https://youtu.be/abc123", .youtube),
            ("https://www.youtube.com/watch?v=abc123", .youtube),
            ("https://www.tiktok.com/@user/video/123", .tiktok),
            ("https://www.douyin.com/video/123", .douyin)
        ]
        for (string, platform) in cases {
            let url = try requiredURL(string)
            try expect(VideoLinkParser.platform(for: url) == platform, "Platform: \(string)")
        }
    }

    private static func testLookalikeDomains() throws {
        let youtubeLookalike = try requiredURL("https://youtube.com.example.com/watch")
        let bilibiliLookalike = try requiredURL("https://notbilibili.com/video")
        try expect(VideoLinkParser.platform(for: youtubeLookalike) == .unknown, "YouTube lookalike")
        try expect(VideoLinkParser.platform(for: bilibiliLookalike) == .unknown, "Bilibili lookalike")
    }

    private static func testCommand() throws {
        let toolchain = ToolchainPaths(
            ytDLP: URL(fileURLWithPath: "/app/yt-dlp"),
            ffmpegDirectory: URL(fileURLWithPath: "/app/tools"),
            javaScriptRuntime: URL(fileURLWithPath: "/app/node")
        )
        let arguments = YTDLPCommandBuilder.downloadArguments(
            url: try requiredURL("https://youtu.be/abc"),
            options: DownloadOptions(
                outputDirectory: URL(fileURLWithPath: "/Users/test/Downloads"),
                quality: .fullHD1080,
                container: .mp4,
                cookieBrowser: .safari
            ),
            toolchain: toolchain
        )
        try expect(arguments.contains("--no-playlist"), "Single video")
        try expect(arguments.contains("--ignore-config"), "Ignore config")
        try expect(arguments.contains("--cookies-from-browser"), "Cookie option")
        try expect(arguments.contains("bestvideo*[height<=?1080][format_note!*=?watermarked]+bestaudio/best[height<=?1080][format_note!*=?watermarked]"), "Quality selector")
        try expect(Array(arguments.suffix(2)) == ["--", "https://youtu.be/abc"], "URL separator")
        try expect(!arguments.contains("--exec"), "No executable hooks")
    }

    private static func testProgress() throws {
        let line = #"VH_PROGRESS:{"downloaded_bytes":500,"total_bytes_estimate":1000,"_percent":50.0,"speed":250.5,"eta":2,"status":"downloading"}"#
        guard let progress = YTDLPOutputParser.progress(from: line) else {
            throw TestFailure(description: "Progress parse")
        }
        try expect(progress.fraction == 0.5, "Progress fraction")
        try expect(progress.downloadedBytes == 500, "Downloaded bytes")
        try expect(progress.totalBytes == 1000, "Total bytes")
    }

    private static func testMetadata() throws {
        let json = #"{"id":"abc","title":"Authorized sample","uploader":"Creator","duration":12.5,"thumbnail":"https://example.com/t.jpg","webpage_url":"https://youtu.be/abc","extractor_key":"Youtube","width":1920,"height":1080,"filesize_approx":12345}"#.data(using: .utf8)!
        let metadata = try YTDLPOutputParser.metadata(
            from: json,
            sourceURL: requiredURL("https://youtu.be/abc"),
            fallbackPlatform: .youtube
        )
        try expect(metadata.id == "abc", "Metadata id")
        try expect(metadata.platform == .youtube, "Metadata platform")
        try expect(metadata.height == 1080, "Metadata height")
    }

    private static func testCookieAccessFailure() throws {
        let safari = "ERROR: [Errno 1] Operation not permitted: /Users/test/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"
        let chromium = "WARNING: cannot decrypt v10 cookies: no key found"
        let login = "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
        try expect(YTDLPOutputParser.isCookieAccessFailure(safari), "Safari cookie permission")
        try expect(YTDLPOutputParser.isCookieAccessFailure(chromium), "Chromium cookie decryption")
        try expect(!YTDLPOutputParser.isCookieAccessFailure(login), "Login requirement is not local cookie access failure")
    }

    private static func testFreshCookieFailure() throws {
        let douyin = "ERROR: [Douyin] 123: Fresh cookies (not necessarily logged in) are needed"
        let login = "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
        try expect(YTDLPOutputParser.isFreshCookieFailure(douyin), "Douyin fresh cookie requirement")
        try expect(!YTDLPOutputParser.isFreshCookieFailure(login), "Ordinary login error must not trigger Douyin bootstrap")
    }
}
