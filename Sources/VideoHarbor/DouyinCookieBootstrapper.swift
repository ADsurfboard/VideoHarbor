import Foundation

struct DouyinBrowserSession {
    let browserName: String
    let profileDirectory: URL

    var cookieSpecification: String {
        "\(browserName):\(profileDirectory.path)"
    }
}

enum DouyinCookieBootstrapError: LocalizedError {
    case chromiumUnavailable
    case launchFailed(String)
    case pageDidNotBecomeReady

    var errorDescription: String? {
        switch self {
        case .chromiumUnavailable:
            return "抖音当前要求浏览器生成新鲜验证信息，但未找到 Google Chrome、Microsoft Edge 或 Brave。"
        case .launchFailed(let message):
            return "无法启动隔离浏览器会话：\(message)"
        case .pageDidNotBecomeReady:
            return "抖音验证页面未能及时加载，请检查网络后重试。"
        }
    }
}

enum DouyinCookieBootstrapper {
    private struct BrowserCandidate {
        let name: String
        let executable: URL
    }

    static func prepare(url: URL, forceRefresh: Bool = false) async throws -> DouyinBrowserSession {
        guard let browser = installedBrowser() else {
            throw DouyinCookieBootstrapError.chromiumUnavailable
        }
        let profile = try profileDirectory()
        let session = DouyinBrowserSession(
            browserName: browser.name,
            profileDirectory: profile
        )
        if !forceRefresh, cachedSessionIsFresh(session) {
            return session
        }

        return try await Task.detached(priority: .userInitiated) {
            var lastError: Error = DouyinCookieBootstrapError.pageDidNotBecomeReady
            for _ in 0..<2 {
                do {
                    try await refresh(
                        browser: browser,
                        profile: profile,
                        url: url
                    )
                    try browser.name.write(
                        to: profile.appendingPathComponent("VideoHarbor.ready"),
                        atomically: true,
                        encoding: .utf8
                    )
                    return session
                } catch {
                    lastError = error
                }
            }
            throw lastError
        }.value
    }

    private static func refresh(
        browser: BrowserCandidate,
        profile: URL,
        url: URL
    ) async throws {
        let fileManager = FileManager.default
        for singleton in ["SingletonCookie", "SingletonLock", "SingletonSocket"] {
            try? fileManager.removeItem(at: profile.appendingPathComponent(singleton))
        }

        let domURL = profile.appendingPathComponent("VideoHarbor.page.html")
        let errorURL = profile.appendingPathComponent("VideoHarbor.browser.log")
        fileManager.createFile(atPath: domURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: domURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        try outputHandle.truncate(atOffset: 0)
        try errorHandle.truncate(atOffset: 0)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = browser.executable
        process.arguments = [
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--disable-background-networking",
            "--disable-default-apps",
            "--disable-sync",
            "--mute-audio",
            "--user-data-dir=\(profile.path)",
            "--virtual-time-budget=5000",
            "--dump-dom",
            url.absoluteString
        ]
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        do {
            try process.run()
        } catch {
            throw DouyinCookieBootstrapError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(50)
        var pageReady = false
        while Date() < deadline {
            try? outputHandle.synchronize()
            if let data = try? Data(contentsOf: domURL),
               let html = String(data: data, encoding: .utf8),
               html.localizedCaseInsensitiveContains("<video"),
               (html.localizedCaseInsensitiveContains("douyinvod.com")
                || html.localizedCaseInsensitiveContains("/aweme/v1/play/")) {
                pageReady = true
                break
            }
            if !process.isRunning { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        if pageReady {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            try? outputHandle.synchronize()
            try? errorHandle.synchronize()
        }
        if process.isRunning {
            process.terminate()
            let terminationDeadline = Date().addingTimeInterval(3)
            while process.isRunning, Date() < terminationDeadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if process.isRunning { process.interrupt() }
        }
        process.waitUntilExit()

        guard pageReady else {
            throw DouyinCookieBootstrapError.pageDidNotBecomeReady
        }
    }

    private static func profileDirectory() throws -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let profile = root
            .appendingPathComponent("VideoHarbor", isDirectory: true)
            .appendingPathComponent("DouyinBrowserProfile", isDirectory: true)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        return profile
    }

    private static func cachedSessionIsFresh(_ session: DouyinBrowserSession) -> Bool {
        let marker = session.profileDirectory.appendingPathComponent("VideoHarbor.ready")
        let cookies = session.profileDirectory.appendingPathComponent("Default/Cookies")
        guard FileManager.default.fileExists(atPath: cookies.path),
              let browserName = try? String(contentsOf: marker, encoding: .utf8),
              browserName == session.browserName,
              let attributes = try? FileManager.default.attributesOfItem(atPath: marker.path),
              let modificationDate = attributes[.modificationDate] as? Date
        else { return false }
        return Date().timeIntervalSince(modificationDate) < 20 * 60
    }

    private static func installedBrowser() -> BrowserCandidate? {
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        let candidates: [(String, String)] = [
            ("chrome", "Google Chrome.app/Contents/MacOS/Google Chrome"),
            ("edge", "Microsoft Edge.app/Contents/MacOS/Microsoft Edge"),
            ("brave", "Brave Browser.app/Contents/MacOS/Brave Browser")
        ]
        for (name, relativePath) in candidates {
            for root in [URL(fileURLWithPath: "/Applications", isDirectory: true), homeApplications] {
                let executable = root.appendingPathComponent(relativePath)
                if FileManager.default.isExecutableFile(atPath: executable.path) {
                    return BrowserCandidate(name: name, executable: executable)
                }
            }
        }
        return nil
    }
}
