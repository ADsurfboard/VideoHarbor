import AppKit
import Foundation
import UniformTypeIdentifiers
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

enum HarborSection: String, CaseIterable, Identifiable {
    case extract
    case downloads
    case toolchain
    case settings

    var id: String { rawValue }
}

@MainActor
final class HarborAppModel: ObservableObject {
    @Published var selectedSection: HarborSection = .extract
    @Published var shareText = ""
    @Published var preview: VideoMetadata?
    @Published var preferences: AppPreferences {
        didSet { JSONStore.save(preferences, to: paths.settings) }
    }
    @Published var records: [DownloadRecord] {
        didSet { scheduleHistorySave() }
    }
    @Published var isResolving = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published private(set) var toolchain: ToolchainSnapshot

    private let paths = AppPaths()
    private let engine = VideoEngine()
    private var historySaveTask: Task<Void, Never>?

    init() {
        try? paths.prepare()
        preferences = JSONStore.load(AppPreferences.self, from: paths.settings) ?? AppPreferences()
        records = JSONStore.load([DownloadRecord].self, from: paths.history) ?? []
        toolchain = ToolchainLocator.locate()
        repairInterruptedRecords()
    }

    var activeCount: Int {
        records.filter { $0.status == .queued || $0.status == .downloading || $0.status == .processing }.count
    }

    var completedCount: Int {
        records.filter { $0.status == .completed }.count
    }

    func resolveShareText() {
        guard !isResolving else { return }
        preview = nil
        errorMessage = nil
        let parsed: (URL, VideoPlatform)
        do {
            parsed = try VideoLinkParser.parseSupportedURL(from: shareText)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard let paths = toolchain.paths else {
            errorMessage = VideoEngineError.toolchainUnavailable.localizedDescription
            selectedSection = .toolchain
            return
        }

        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                preview = try await engine.inspect(
                    url: parsed.0,
                    platform: parsed.1,
                    cookieBrowser: preferences.cookieBrowser,
                    toolchain: paths
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func downloadPreview() {
        guard let preview, let toolchain = toolchain.paths else { return }
        let output = URL(fileURLWithPath: preferences.outputDirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            errorMessage = "无法创建下载目录：\(error.localizedDescription)"
            return
        }

        var record = DownloadRecord(
            sourceURL: preview.webpageURL,
            title: preview.title,
            platform: preview.platform
        )
        record.status = .downloading
        records.insert(record, at: 0)
        selectedSection = .downloads

        let options = DownloadOptions(
            outputDirectory: output,
            quality: preferences.quality,
            container: preferences.container,
            cookieBrowser: preferences.cookieBrowser
        )
        let id = record.id
        Task {
            do {
                let path = try await engine.download(
                    id: id,
                    url: preview.webpageURL,
                    options: options,
                    toolchain: toolchain
                ) { [weak self] line in
                    Task { @MainActor in self?.consume(line: line, for: id) }
                }
                updateRecord(id: id) {
                    $0.status = .completed
                    $0.progress = 1
                    $0.outputPath = path
                    $0.updatedAt = Date()
                }
                toastMessage = "视频已保存"
            } catch {
                let current = records.first { $0.id == id }
                if current?.status != .cancelled {
                    updateRecord(id: id) {
                        $0.status = .failed
                        $0.errorMessage = error.localizedDescription
                        $0.updatedAt = Date()
                    }
                }
            }
        }
    }

    func cancel(_ id: UUID) {
        engine.cancel(id: id)
        updateRecord(id: id) {
            $0.status = .cancelled
            $0.errorMessage = nil
            $0.updatedAt = Date()
        }
    }

    func retry(_ record: DownloadRecord) {
        shareText = record.sourceURL.absoluteString
        selectedSection = .extract
        resolveShareText()
    }

    func remove(_ id: UUID) {
        guard let record = records.first(where: { $0.id == id }), record.status.isTerminal else { return }
        records.removeAll { $0.id == id }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func open(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择视频保存位置"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: preferences.outputDirectory)
        if panel.runModal() == .OK, let url = panel.url {
            preferences.outputDirectory = url.path
        }
    }

    func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.title = "选择静态或动态壁纸"
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            let destination = uniqueWallpaperDestination(for: source)
            try FileManager.default.copyItem(at: source, to: destination)
            let kind: WallpaperKind = UTType(filenameExtension: source.pathExtension)?.conforms(to: .movie) == true
                ? .video
                : .image
            preferences.wallpaper.kind = kind
            preferences.wallpaper.filePath = destination.path
        } catch {
            errorMessage = "无法导入壁纸：\(error.localizedDescription)"
        }
    }

    func useBuiltInWallpaper() {
        preferences.wallpaper.kind = .harbor
        preferences.wallpaper.filePath = nil
    }

    func refreshToolchain() {
        toolchain = ToolchainLocator.locate()
        toastMessage = toolchain.isReady ? "工具链已就绪" : "工具链仍不完整"
    }

    func dismissToast() {
        toastMessage = nil
    }

    private func consume(line: String, for id: UUID) {
        if let progress = YTDLPOutputParser.progress(from: line) {
            updateRecord(id: id) {
                $0.status = progress.status == "finished" ? .processing : .downloading
                $0.progress = progress.fraction
                $0.downloadedBytes = progress.downloadedBytes
                $0.totalBytes = progress.totalBytes
                $0.bytesPerSecond = progress.bytesPerSecond
                $0.etaSeconds = progress.etaSeconds
                $0.updatedAt = Date()
            }
        }
    }

    private func updateRecord(id: UUID, change: (inout DownloadRecord) -> Void) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        change(&records[index])
    }

    private func scheduleHistorySave() {
        historySaveTask?.cancel()
        let snapshot = records
        let destination = paths.history
        if snapshot.allSatisfy({ $0.status.isTerminal }) {
            JSONStore.save(snapshot, to: destination)
            return
        }
        historySaveTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            JSONStore.save(snapshot, to: destination)
        }
    }

    private func repairInterruptedRecords() {
        var repaired = records
        for index in repaired.indices where !repaired[index].status.isTerminal {
            repaired[index].status = .failed
            repaired[index].errorMessage = "上次下载在应用退出时中断。"
            repaired[index].updatedAt = Date()
        }
        records = repaired
    }

    private func uniqueWallpaperDestination(for source: URL) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = paths.wallpapers.appendingPathComponent("\(base).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = paths.wallpapers.appendingPathComponent("\(base)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
