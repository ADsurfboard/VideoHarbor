import Foundation
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

enum VideoEngineError: LocalizedError {
    case toolchainUnavailable
    case launchFailed(String)
    case commandFailed(Int32, String)
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .toolchainUnavailable:
            return "下载内核不完整，请在「工具链」页检查 yt-dlp 和 ffmpeg。"
        case .launchFailed(let message):
            return "无法启动下载内核：\(message)"
        case .commandFailed(_, let output):
            return YTDLPOutputParser.friendlyError(from: output)
        case .missingOutputFile:
            return "下载进程已结束，但没有报告最终文件路径。"
        }
    }
}

final class VideoEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var processes: [UUID: Process] = [:]

    func inspect(
        url: URL,
        platform: VideoPlatform,
        cookieBrowser: CookieBrowser,
        toolchain: ToolchainPaths
    ) async throws -> VideoMetadata {
        var arguments = YTDLPCommandBuilder.metadataArguments(
            url: url,
            cookieBrowser: cookieBrowser,
            toolchain: toolchain
        )
        var result = try await runBuffered(executable: toolchain.ytDLP, arguments: arguments)
        if cookieBrowser != .none,
           result.status != 0,
           YTDLPOutputParser.isCookieAccessFailure(result.stderr) {
            arguments = YTDLPCommandBuilder.metadataArguments(
                url: url,
                cookieBrowser: .none,
                toolchain: toolchain
            )
            result = try await runBuffered(executable: toolchain.ytDLP, arguments: arguments)
        }
        if platform == .douyin,
           result.status != 0,
           YTDLPOutputParser.isFreshCookieFailure(result.stderr) {
            var session = try await DouyinCookieBootstrapper.prepare(url: url)
            arguments = argumentsUsingIsolatedBrowser(
                YTDLPCommandBuilder.metadataArguments(
                    url: url,
                    cookieBrowser: .none,
                    toolchain: toolchain
                ),
                session: session
            )
            result = try await runBuffered(executable: toolchain.ytDLP, arguments: arguments)
            if result.status != 0,
               YTDLPOutputParser.isFreshCookieFailure(result.stderr) {
                session = try await DouyinCookieBootstrapper.prepare(url: url, forceRefresh: true)
                arguments = argumentsUsingIsolatedBrowser(
                    YTDLPCommandBuilder.metadataArguments(
                        url: url,
                        cookieBrowser: .none,
                        toolchain: toolchain
                    ),
                    session: session
                )
                result = try await runBuffered(executable: toolchain.ytDLP, arguments: arguments)
            }
        }
        guard result.status == 0 else {
            throw VideoEngineError.commandFailed(result.status, result.stderr)
        }
        return try YTDLPOutputParser.metadata(
            from: result.stdout,
            sourceURL: url,
            fallbackPlatform: platform
        )
    }

    func download(
        id: UUID,
        url: URL,
        options: DownloadOptions,
        toolchain: ToolchainPaths,
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var arguments = YTDLPCommandBuilder.downloadArguments(
            url: url,
            options: options,
            toolchain: toolchain
        )
        var result = try await runStreaming(
            id: id,
            executable: toolchain.ytDLP,
            arguments: arguments,
            onLine: onLine
        )
        if options.cookieBrowser != .none,
           result.status != 0,
           YTDLPOutputParser.isCookieAccessFailure(result.output) {
            var publicOptions = options
            publicOptions.cookieBrowser = .none
            arguments = YTDLPCommandBuilder.downloadArguments(
                url: url,
                options: publicOptions,
                toolchain: toolchain
            )
            result = try await runStreaming(
                id: id,
                executable: toolchain.ytDLP,
                arguments: arguments,
                onLine: onLine
            )
        }
        if result.status != 0,
           YTDLPOutputParser.isFreshCookieFailure(result.output) {
            var session = try await DouyinCookieBootstrapper.prepare(url: url)
            var publicOptions = options
            publicOptions.cookieBrowser = .none
            arguments = argumentsUsingIsolatedBrowser(
                YTDLPCommandBuilder.downloadArguments(
                    url: url,
                    options: publicOptions,
                    toolchain: toolchain
                ),
                session: session
            )
            result = try await runStreaming(
                id: id,
                executable: toolchain.ytDLP,
                arguments: arguments,
                onLine: onLine
            )
            if result.status != 0,
               YTDLPOutputParser.isFreshCookieFailure(result.output) {
                session = try await DouyinCookieBootstrapper.prepare(url: url, forceRefresh: true)
                arguments = argumentsUsingIsolatedBrowser(
                    YTDLPCommandBuilder.downloadArguments(
                        url: url,
                        options: publicOptions,
                        toolchain: toolchain
                    ),
                    session: session
                )
                result = try await runStreaming(
                    id: id,
                    executable: toolchain.ytDLP,
                    arguments: arguments,
                    onLine: onLine
                )
            }
        }
        guard result.status == 0 else {
            throw VideoEngineError.commandFailed(result.status, result.output)
        }
        guard let path = result.lines.compactMap(YTDLPOutputParser.finalPath(from:)).last else {
            throw VideoEngineError.missingOutputFile
        }
        return path
    }

    func cancel(id: UUID) {
        lock.lock()
        let process = processes[id]
        lock.unlock()
        guard let process, process.isRunning else { return }
        process.interrupt()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
            if process.isRunning { process.terminate() }
        }
    }

    private func argumentsUsingIsolatedBrowser(
        _ arguments: [String],
        session: DouyinBrowserSession
    ) -> [String] {
        var result = arguments
        let insertionIndex = result.firstIndex(of: "--") ?? result.endIndex
        result.insert(contentsOf: [
            "--cookies-from-browser",
            session.cookieSpecification
        ], at: insertionIndex)
        return result
    }

    private func runBuffered(
        executable: URL,
        arguments: [String]
    ) async throws -> (status: Int32, stdout: Data, stderr: String) {
        try await Task.detached(priority: .userInitiated) {
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("VideoHarbor-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: temporary) }

            let stdoutURL = temporary.appendingPathComponent("stdout")
            let stderrURL = temporary.appendingPathComponent("stderr")
            FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
            }

            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle
            do {
                try process.run()
            } catch {
                throw VideoEngineError.launchFailed(error.localizedDescription)
            }
            process.waitUntilExit()
            try stdoutHandle.synchronize()
            try stderrHandle.synchronize()
            return (
                process.terminationStatus,
                (try? Data(contentsOf: stdoutURL)) ?? Data(),
                String(decoding: (try? Data(contentsOf: stderrURL)) ?? Data(), as: UTF8.self)
            )
        }.value
    }

    private func runStreaming(
        id: UUID,
        executable: URL,
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> (status: Int32, output: String, lines: [String]) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let state = StreamingState(onLine: onLine)
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { state.consume(data) }
            }

            process.terminationHandler = { [weak self] finished in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remainder.isEmpty { state.consume(remainder) }
                let lines = state.finish()
                self?.lock.lock()
                self?.processes[id] = nil
                self?.lock.unlock()
                continuation.resume(returning: (
                    finished.terminationStatus,
                    lines.joined(separator: "\n"),
                    lines
                ))
            }

            do {
                try process.run()
                lock.lock()
                processes[id] = process
                lock.unlock()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: VideoEngineError.launchFailed(error.localizedDescription))
            }
        }
    }
}

private final class StreamingState: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [String] = []
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func consume(_ data: Data) {
        var emitted: [String] = []
        lock.lock()
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            let line = String(decoding: lineData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                lines.append(line)
                emitted.append(line)
            }
        }
        lock.unlock()
        emitted.forEach(onLine)
    }

    func finish() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if !buffer.isEmpty {
            let line = String(decoding: buffer, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                lines.append(line)
                onLine(line)
            }
            buffer.removeAll()
        }
        return lines
    }
}
