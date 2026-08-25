import Foundation
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct ToolchainSnapshot: Equatable {
    var paths: ToolchainPaths?
    var ytDLPVersion: String?
    var ffmpegVersion: String?
    var runtimeVersion: String?
    var missingTools: [String]

    var isReady: Bool { paths != nil && missingTools.isEmpty }
}

enum ToolchainLocator {
    static func locate() -> ToolchainSnapshot {
        let bundledTools = Bundle.main.resourceURL?.appendingPathComponent("Tools", isDirectory: true)
        let sourceTools = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Tools", isDirectory: true)

        let ytDLP = firstExecutable([
            bundledTools?.appendingPathComponent("yt-dlp"),
            sourceTools.appendingPathComponent("yt-dlp"),
            URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"),
            URL(fileURLWithPath: "/usr/local/bin/yt-dlp")
        ])

        let ffmpeg = firstExecutable([
            bundledTools?.appendingPathComponent("ffmpeg"),
            sourceTools.appendingPathComponent("ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        ])

        let deno = firstExecutable([
            bundledTools?.appendingPathComponent("deno"),
            sourceTools.appendingPathComponent("deno"),
            URL(fileURLWithPath: "/opt/homebrew/bin/deno"),
            URL(fileURLWithPath: "/usr/local/bin/deno")
        ])
        let node = firstExecutable([
            bundledTools?.appendingPathComponent("node"),
            sourceTools.appendingPathComponent("node"),
            URL(fileURLWithPath: "/opt/homebrew/bin/node"),
            URL(fileURLWithPath: "/usr/local/bin/node")
        ])
        let runtime = deno ?? node
        let runtimeName = deno == nil ? "node" : "deno"

        let ytDLPVersion = ytDLP.flatMap { version(of: $0, arguments: ["--version"]) }
        let ffmpegVersion = ffmpeg.flatMap {
            version(of: $0, arguments: ["-version"])?.split(separator: "\n").first.map(String.init)
        }
        let runtimeVersion = runtime.flatMap { version(of: $0, arguments: ["--version"]) }

        let usableYTDLP = ytDLPVersion == nil ? nil : ytDLP
        let usableFFmpeg = ffmpegVersion == nil ? nil : ffmpeg
        let usableRuntime = runtimeVersion == nil ? nil : runtime

        var missing: [String] = []
        if usableYTDLP == nil { missing.append("yt-dlp") }
        if usableFFmpeg == nil { missing.append("ffmpeg") }
        if usableRuntime == nil { missing.append("Node/Deno") }

        let paths: ToolchainPaths?
        if let usableYTDLP, let usableFFmpeg, let usableRuntime {
            paths = ToolchainPaths(
                ytDLP: usableYTDLP,
                ffmpegDirectory: usableFFmpeg.deletingLastPathComponent(),
                javaScriptRuntime: usableRuntime,
                javaScriptRuntimeName: runtimeName
            )
        } else {
            paths = nil
        }

        return ToolchainSnapshot(
            paths: paths,
            ytDLPVersion: ytDLPVersion,
            ffmpegVersion: ffmpegVersion,
            runtimeVersion: runtimeVersion,
            missingTools: missing
        )
    }

    private static func firstExecutable(_ candidates: [URL?]) -> URL? {
        candidates.compactMap { $0 }.first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    private static func version(of executable: URL, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(
                decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
