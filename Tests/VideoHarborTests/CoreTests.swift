import Foundation
import XCTest
@testable import VideoHarborCore

final class CoreTests: XCTestCase {
func testExtractsURLFromChineseShareText() throws {
    let input = "3.21 复制打开抖音，看看【测试】 https://v.douyin.com/AbCdEf/ 长按复制此条消息。"
    let result = try VideoLinkParser.parseSupportedURL(from: input)
    XCTAssertEqual(result.0.absoluteString, "https://v.douyin.com/AbCdEf/")
    XCTAssertEqual(result.1, .douyin)
}

func testRecognizesSupportedPlatforms() throws {
    let cases: [(String, VideoPlatform)] = [
        ("https://www.bilibili.com/video/BV123", .bilibili),
        ("https://b23.tv/abcd", .bilibili),
        ("https://youtu.be/abc123", .youtube),
        ("https://www.youtube.com/watch?v=abc123", .youtube),
        ("https://www.tiktok.com/@user/video/123", .tiktok),
        ("https://www.douyin.com/video/123", .douyin)
    ]
    for (urlString, platform) in cases {
        XCTAssertEqual(VideoLinkParser.platform(for: try XCTUnwrap(URL(string: urlString))), platform)
    }
}

func testRejectsLookalikeDomains() throws {
    XCTAssertEqual(VideoLinkParser.platform(for: try XCTUnwrap(URL(string: "https://youtube.com.example.com/watch"))), .unknown)
    XCTAssertEqual(VideoLinkParser.platform(for: try XCTUnwrap(URL(string: "https://notbilibili.com/video"))), .unknown)
}

func testBuildsSafeSingleVideoCommand() throws {
    let toolchain = ToolchainPaths(
        ytDLP: URL(fileURLWithPath: "/app/yt-dlp"),
        ffmpegDirectory: URL(fileURLWithPath: "/app/tools"),
        javaScriptRuntime: URL(fileURLWithPath: "/app/node")
    )
    let arguments = YTDLPCommandBuilder.downloadArguments(
        url: try XCTUnwrap(URL(string: "https://youtu.be/abc")),
        options: DownloadOptions(
            outputDirectory: URL(fileURLWithPath: "/Users/test/Downloads"),
            quality: .fullHD1080,
            container: .mp4,
            cookieBrowser: .safari
        ),
        toolchain: toolchain
    )
    XCTAssertTrue(arguments.contains("--no-playlist"))
    XCTAssertTrue(arguments.contains("--ignore-config"))
    XCTAssertTrue(arguments.contains("--cookies-from-browser"))
    XCTAssertTrue(arguments.contains("bestvideo*[height<=?1080][format_note!*=?watermarked]+bestaudio/best[height<=?1080][format_note!*=?watermarked]"))
    XCTAssertEqual(Array(arguments.suffix(2)), ["--", "https://youtu.be/abc"])
    XCTAssertFalse(arguments.contains("--exec"))
}

func testParsesProgressJSON() throws {
    let line = #"VH_PROGRESS:{"downloaded_bytes":500,"total_bytes_estimate":1000,"_percent":50.0,"speed":250.5,"eta":2,"status":"downloading"}"#
    let progress = try XCTUnwrap(YTDLPOutputParser.progress(from: line))
    XCTAssertEqual(progress.fraction, 0.5)
    XCTAssertEqual(progress.downloadedBytes, 500)
    XCTAssertEqual(progress.totalBytes, 1000)
    XCTAssertEqual(progress.bytesPerSecond, 250.5)
    XCTAssertEqual(progress.etaSeconds, 2)
}

func testParsesMetadata() throws {
    let json = #"{"id":"abc","title":"Authorized sample","uploader":"Creator","duration":12.5,"thumbnail":"https://example.com/t.jpg","webpage_url":"https://youtu.be/abc","extractor_key":"Youtube","width":1920,"height":1080,"filesize_approx":12345}"#.data(using: .utf8)!
    let metadata = try YTDLPOutputParser.metadata(
        from: json,
        sourceURL: URL(string: "https://youtu.be/abc")!,
        fallbackPlatform: .youtube
    )
    XCTAssertEqual(metadata.id, "abc")
    XCTAssertEqual(metadata.title, "Authorized sample")
    XCTAssertEqual(metadata.platform, .youtube)
    XCTAssertEqual(metadata.height, 1080)
}

func testDetectsLocalCookieAccessFailures() {
    XCTAssertTrue(YTDLPOutputParser.isCookieAccessFailure(
        "ERROR: [Errno 1] Operation not permitted: '/Users/test/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies'"
    ))
    XCTAssertTrue(YTDLPOutputParser.isCookieAccessFailure(
        "WARNING: cannot decrypt v10 cookies: no key found"
    ))
    XCTAssertFalse(YTDLPOutputParser.isCookieAccessFailure(
        "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
    ))
}

func testDetectsDouyinFreshCookieFailure() {
    XCTAssertTrue(YTDLPOutputParser.isFreshCookieFailure(
        "ERROR: [Douyin] 123: Fresh cookies (not necessarily logged in) are needed"
    ))
    XCTAssertFalse(YTDLPOutputParser.isFreshCookieFailure(
        "ERROR: Sign in to confirm you are not a bot. Use --cookies-from-browser"
    ))
}
}
