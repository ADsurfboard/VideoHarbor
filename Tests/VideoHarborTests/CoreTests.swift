import Foundation
import Testing
@testable import VideoHarborCore

@Test func extractsURLFromChineseShareText() throws {
    let input = "3.21 复制打开抖音，看看【测试】 https://v.douyin.com/AbCdEf/ 长按复制此条消息。"
    let result = try VideoLinkParser.parseSupportedURL(from: input)
    #expect(result.0.absoluteString == "https://v.douyin.com/AbCdEf/")
    #expect(result.1 == .douyin)
}

@Test(arguments: [
    ("https://www.bilibili.com/video/BV123", VideoPlatform.bilibili),
    ("https://b23.tv/abcd", VideoPlatform.bilibili),
    ("https://youtu.be/abc123", VideoPlatform.youtube),
    ("https://www.youtube.com/watch?v=abc123", VideoPlatform.youtube),
    ("https://www.tiktok.com/@user/video/123", VideoPlatform.tiktok),
    ("https://www.douyin.com/video/123", VideoPlatform.douyin)
])
func recognizesSupportedPlatforms(url: String, platform: VideoPlatform) throws {
    #expect(VideoLinkParser.platform(for: try #require(URL(string: url))) == platform)
}

@Test func rejectsLookalikeDomains() throws {
    #expect(VideoLinkParser.platform(for: try #require(URL(string: "https://youtube.com.example.com/watch"))) == .unknown)
    #expect(VideoLinkParser.platform(for: try #require(URL(string: "https://notbilibili.com/video"))) == .unknown)
}

@Test func buildsSafeSingleVideoCommand() throws {
    let toolchain = ToolchainPaths(
        ytDLP: URL(fileURLWithPath: "/app/yt-dlp"),
        ffmpegDirectory: URL(fileURLWithPath: "/app/tools"),
        javaScriptRuntime: URL(fileURLWithPath: "/app/node")
    )
    let arguments = YTDLPCommandBuilder.downloadArguments(
        url: try #require(URL(string: "https://youtu.be/abc")),
        options: DownloadOptions(
            outputDirectory: URL(fileURLWithPath: "/Users/test/Downloads"),
            quality: .fullHD1080,
            container: .mp4,
            cookieBrowser: .safari
        ),
        toolchain: toolchain
    )
    #expect(arguments.contains("--no-playlist"))
    #expect(arguments.contains("--ignore-config"))
    #expect(arguments.contains("--cookies-from-browser"))
    #expect(arguments.contains("bestvideo*[height<=?1080][format_note!*=?watermarked]+bestaudio/best[height<=?1080][format_note!*=?watermarked]"))
    #expect(arguments.suffix(2) == ["--", "https://youtu.be/abc"])
    #expect(!arguments.contains("--exec"))
}

@Test func parsesProgressJSON() throws {
    let line = #"VH_PROGRESS:{"downloaded_bytes":500,"total_bytes_estimate":1000,"_percent":50.0,"speed":250.5,"eta":2,"status":"downloading"}"#
    let progress = try #require(YTDLPOutputParser.progress(from: line))
    #expect(progress.fraction == 0.5)
    #expect(progress.downloadedBytes == 500)
    #expect(progress.totalBytes == 1000)
    #expect(progress.bytesPerSecond == 250.5)
    #expect(progress.etaSeconds == 2)
}

@Test func parsesMetadata() throws {
    let json = #"{"id":"abc","title":"Authorized sample","uploader":"Creator","duration":12.5,"thumbnail":"https://example.com/t.jpg","webpage_url":"https://youtu.be/abc","extractor_key":"Youtube","width":1920,"height":1080,"filesize_approx":12345}"#.data(using: .utf8)!
    let metadata = try YTDLPOutputParser.metadata(
        from: json,
        sourceURL: URL(string: "https://youtu.be/abc")!,
        fallbackPlatform: .youtube
    )
    #expect(metadata.id == "abc")
    #expect(metadata.title == "Authorized sample")
    #expect(metadata.platform == .youtube)
    #expect(metadata.height == 1080)
}

@Test func detectsLocalCookieAccessFailures() {
    #expect(YTDLPOutputParser.isCookieAccessFailure(
        "ERROR: [Errno 1] Operation not permitted: '/Users/test/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies'"
    ))
    #expect(YTDLPOutputParser.isCookieAccessFailure(
        "WARNING: cannot decrypt v10 cookies: no key found"
    ))
    #expect(!YTDLPOutputParser.isCookieAccessFailure(
        "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
    ))
}

@Test func detectsDouyinFreshCookieFailure() {
    #expect(YTDLPOutputParser.isFreshCookieFailure(
        "ERROR: [Douyin] 123: Fresh cookies (not necessarily logged in) are needed"
    ))
    #expect(!YTDLPOutputParser.isFreshCookieFailure(
        "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
    ))
}
