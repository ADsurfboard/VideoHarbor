import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct DownloadsView: View {
    @ObservedObject var model: HarborAppModel
    var body: some View {
        let appearance = model.preferences.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    HarborSectionHeader(
                        eyebrow: "Download Dock",
                        title: "下载船坞",
                        detail: "查看实时进度、合并状态与历史文件。",
                        appearance: appearance
                    )
                    Spacer()
                    HarborStatusPill(title: "\(model.activeCount) 正在运行", color: model.activeCount > 0 ? HarborPalette.amber : HarborPalette.seaGlass)
                }
                if model.records.isEmpty {
                    HarborEmptyState(icon: "tray", title: "船坞还没有任务", detail: "回到「提取」粘贴一条视频分享链接。", appearance: appearance)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.records) { record in DownloadRow(model: model, record: record) }
                    }
                }
            }
            .padding(28).padding(.bottom, 20)
        }
    }
}

private struct DownloadRow: View {
    @ObservedObject var model: HarborAppModel
    let record: DownloadRecord
    var body: some View {
        let appearance = model.preferences.appearance
        let theme = HarborTheme(appearance: appearance)
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(statusColor.opacity(0.12))
                Image(systemName: record.platform.symbolName).font(.system(size: 20, weight: .semibold)).foregroundStyle(statusColor)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(record.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer()
                    HarborStatusPill(title: statusTitle, color: statusColor)
                }
                if record.status == .downloading || record.status == .processing {
                    ProgressView(value: record.progress).tint(HarborPalette.seaGlass)
                    HStack {
                        Text(progressDetail)
                        Spacer()
                        if let eta = record.etaSeconds { Text("ETA \(Int(eta))s") }
                    }
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(theme.secondaryText)
                } else if let error = record.errorMessage {
                    Text(error).font(.system(size: 10)).foregroundStyle(HarborPalette.amber).lineLimit(2)
                } else if let path = record.outputPath {
                    Text(path).font(.system(size: 9, design: .monospaced)).foregroundStyle(theme.secondaryText).lineLimit(1).truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                if record.status == .downloading || record.status == .processing {
                    Button { model.cancel(record.id) } label: { Image(systemName: "xmark") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                } else if record.status == .completed, let path = record.outputPath {
                    Button { model.open(path) } label: { Image(systemName: "play.fill") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance, prominent: true))
                    Button { model.reveal(path) } label: { Image(systemName: "folder") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                } else {
                    Button { model.retry(record) } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                }
                if record.status.isTerminal {
                    Button { model.remove(record.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                }
            }
        }
        .padding(16).harborGlass(appearance: appearance, radius: 20)
    }

    private var statusTitle: String {
        switch record.status {
        case .queued: return "排队"
        case .downloading: return "下载"
        case .processing: return "合并"
        case .completed: return "完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
    private var statusColor: Color {
        switch record.status {
        case .completed: return HarborPalette.seaGlass
        case .failed, .cancelled: return HarborPalette.copper
        case .downloading, .processing: return HarborPalette.amber
        case .queued: return HarborPalette.oxide
        }
    }
    private var progressDetail: String {
        var parts = [String(format: "%.1f%%", record.progress * 100)]
        if let downloaded = record.downloadedBytes { parts.append(downloaded.harborBytes) }
        if let total = record.totalBytes { parts.append("/ \(total.harborBytes)") }
        if let speed = record.bytesPerSecond { parts.append("\(Int64(speed).harborBytes)/s") }
        return parts.joined(separator: " ")
    }
}
