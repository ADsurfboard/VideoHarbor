import AppKit
import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct ExtractView: View {
    @ObservedObject var model: HarborAppModel
    @State private var confirmsRights = false

    var body: some View {
        let appearance = model.preferences.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HarborSectionHeader(
                    eyebrow: "Share Link / Source Stream",
                    title: "粘贴链接，载入原始源流",
                    detail: "可直接粘贴完整分享文本，VideoHarbor 会自动找到其中的视频链接。",
                    appearance: appearance
                )

                LinkInputCard(model: model)

                if let preview = model.preview {
                    PreviewCard(model: model, metadata: preview, confirmsRights: $confirmsRights)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(28).padding(.bottom, 20)
        }
    }
}

private struct LinkInputCard: View {
    @ObservedObject var model: HarborAppModel
    var body: some View {
        let appearance = model.preferences.appearance
        let theme = HarborTheme(appearance: appearance)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("分享链接或文本", systemImage: "link")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("HTTPS ONLY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(theme.secondaryText)
            }
            ZStack(alignment: .topLeading) {
                if model.shareText.isEmpty {
                    Text("例如：3.21 复制打开抖音… https://v.douyin.com/xxxx/")
                        .font(.system(size: 13)).foregroundStyle(theme.secondaryText.opacity(0.7)).padding(13)
                }
                TextEditor(text: $model.shareText)
                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                    .frame(minHeight: 74, maxHeight: 110).padding(5)
            }
            .background(theme.sidebarTint.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.border, lineWidth: 0.7) }

            HStack {
                Button {
                    model.shareText = NSPasteboard.general.string(forType: .string) ?? ""
                } label: { Label("粘贴", systemImage: "doc.on.clipboard") }
                .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                Button {
                    model.shareText = ""
                    model.preview = nil
                } label: { Text("清空") }
                .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                Spacer()
                if model.isResolving {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在解析源流…").font(.system(size: 11)).foregroundStyle(theme.secondaryText)
                    }
                }
                Button(action: model.resolveShareText) {
                    Label("解析视频", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(HarborActionButtonStyle(appearance: appearance, prominent: true))
                .disabled(model.shareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isResolving)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(20).harborGlass(appearance: appearance)
    }
}

private struct PreviewCard: View {
    @ObservedObject var model: HarborAppModel
    let metadata: VideoMetadata
    @Binding var confirmsRights: Bool
    var body: some View {
        let appearance = model.preferences.appearance
        let theme = HarborTheme(appearance: appearance)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 20) {
                AsyncImage(url: metadata.thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            LinearGradient(colors: [HarborPalette.oxide.opacity(0.55), HarborPalette.nightRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: metadata.platform.symbolName).font(.system(size: 34)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                .frame(width: 286, height: 161).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 0.7) }

                VStack(alignment: .leading, spacing: 10) {
                    HarborStatusPill(title: metadata.platform.displayName, color: HarborPalette.seaGlass)
                    Text(metadata.title).font(.system(size: 21, weight: .semibold, design: .serif)).lineLimit(3)
                    if let uploader = metadata.uploader {
                        Label(uploader, systemImage: "person.crop.circle").font(.system(size: 11)).foregroundStyle(theme.secondaryText)
                    }
                    HStack(spacing: 12) {
                        if let duration = metadata.duration { Label(duration.harborDuration, systemImage: "clock") }
                        if let width = metadata.width, let height = metadata.height { Label("\(width)×\(height)", systemImage: "rectangle.expand.vertical") }
                        if let size = metadata.estimatedFileSize { Label(size.harborBytes, systemImage: "externaldrive") }
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(theme.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 161, alignment: .topLeading)
            }

            Divider().opacity(0.22)
            HStack(spacing: 14) {
                optionPicker("清晰度", selection: $model.preferences.quality, values: DownloadQuality.allCases)
                optionPicker("封装", selection: $model.preferences.container, values: MediaContainer.allCases)
                VStack(alignment: .leading, spacing: 5) {
                    Text("保存位置").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(theme.secondaryText)
                    Button(action: model.chooseOutputDirectory) {
                        Label(URL(fileURLWithPath: model.preferences.outputDirectory).lastPathComponent, systemImage: "folder")
                            .lineLimit(1).frame(maxWidth: 170, alignment: .leading)
                    }
                    .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                }
                Spacer()
            }
            Toggle(isOn: $confirmsRights) {
                Text("我确认自己拥有或已获得下载该内容的授权")
                    .font(.system(size: 11)).foregroundStyle(theme.secondaryText)
            }
            .toggleStyle(.checkbox)
            HStack {
                Label("下载平台公开提供的原始源流；不绕过 DRM，不对画面水印做擦除。", systemImage: "checkmark.shield")
                    .font(.system(size: 10)).foregroundStyle(theme.secondaryText)
                Spacer()
                Button(action: model.downloadPreview) { Label("开始提取", systemImage: "arrow.down.circle.fill") }
                    .buttonStyle(HarborActionButtonStyle(appearance: appearance, prominent: true))
                    .disabled(!confirmsRights)
            }
        }
        .padding(20).harborGlass(appearance: appearance)
    }

    private func optionPicker<Value: Hashable & Identifiable>(
        _ title: String,
        selection: Binding<Value>,
        values: [Value]
    ) -> some View where Value.ID == String {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(HarborTheme(appearance: model.preferences.appearance).secondaryText)
            Picker(title, selection: selection) {
                ForEach(values) { value in
                    if let quality = value as? DownloadQuality { Text(quality.displayName).tag(value) }
                    else if let container = value as? MediaContainer { Text(container.displayName).tag(value) }
                }
            }
            .labelsHidden().frame(width: 145)
        }
    }
}
