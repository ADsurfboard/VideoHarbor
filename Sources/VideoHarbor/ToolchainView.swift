import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct ToolchainView: View {
    @ObservedObject var model: HarborAppModel
    var body: some View {
        let appearance = model.preferences.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    HarborSectionHeader(
                        eyebrow: "Extraction Toolchain",
                        title: "提取工具链",
                        detail: "yt-dlp 负责识别站点和源流，ffmpeg 负责无损合并音视频。",
                        appearance: appearance
                    )
                    Spacer()
                    Button(action: model.refreshToolchain) { Label("重新检查", systemImage: "arrow.clockwise") }
                        .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                }

                HStack(spacing: 14) {
                    ToolCard(name: "yt-dlp", role: "EXTRACTOR", version: model.toolchain.ytDLPVersion, ready: model.toolchain.paths != nil, appearance: appearance)
                    ToolCard(name: "ffmpeg", role: "MEDIA MERGER", version: model.toolchain.ffmpegVersion, ready: !model.toolchain.missingTools.contains("ffmpeg"), appearance: appearance)
                    ToolCard(name: "Deno / Node", role: "JS RUNTIME", version: model.toolchain.runtimeVersion, ready: model.toolchain.runtimeVersion != nil, appearance: appearance, optional: true)
                }

                VStack(alignment: .leading, spacing: 13) {
                    Label("运行方式", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(HarborPalette.seaGlass)
                    Text("所有工具都作为 VideoHarbor 的本地子进程运行。链接仅发送给相应平台，不经过 VideoHarbor 中转服务器；Cookie 内容不写入任务历史和日志。")
                        .font(.system(size: 12)).foregroundStyle(HarborTheme(appearance: appearance).secondaryText).fixedSize(horizontal: false, vertical: true)
                    if let paths = model.toolchain.paths {
                        Divider().opacity(0.2)
                        pathRow("YT-DLP", paths.ytDLP.path, appearance: appearance)
                        if let ffmpeg = paths.ffmpegDirectory { pathRow("FFMPEG", ffmpeg.path, appearance: appearance) }
                        if let runtime = paths.javaScriptRuntime { pathRow(paths.javaScriptRuntimeName.uppercased(), runtime.path, appearance: appearance) }
                    }
                }
                .padding(20).harborGlass(appearance: appearance)

                if !model.toolchain.isReady {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("发布包工具不完整", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(HarborPalette.amber)
                        Text("缺少：\(model.toolchain.missingTools.joined(separator: ", "))。正式 VideoHarbor.app 会捆绑这些组件；从源码运行时，也会查找 /opt/homebrew/bin 与 /usr/local/bin。")
                            .font(.system(size: 11)).foregroundStyle(HarborTheme(appearance: appearance).secondaryText)
                    }
                    .padding(18).harborGlass(appearance: appearance, radius: 18)
                }
            }
            .padding(28).padding(.bottom, 20)
        }
    }

    private func pathRow(_ label: String, _ path: String, appearance: HarborAppearance) -> some View {
        HStack {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(HarborPalette.seaGlass).frame(width: 72, alignment: .leading)
            Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(HarborTheme(appearance: appearance).secondaryText).lineLimit(1).truncationMode(.middle)
        }
    }
}

private struct ToolCard: View {
    let name: String
    let role: String
    let version: String?
    let ready: Bool
    let appearance: HarborAppearance
    var optional = false
    var body: some View {
        let color = ready ? HarborPalette.seaGlass : (optional ? HarborPalette.oxide : HarborPalette.amber)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: ready ? "checkmark.circle.fill" : (optional ? "circle.dotted" : "exclamationmark.circle.fill")).foregroundStyle(color)
                Spacer()
                Text(role).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(color)
            }
            Text(name).font(.system(size: 18, weight: .semibold, design: .serif))
            Text(version ?? (optional ? "可选，YouTube 解密时建议" : "未找到"))
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(HarborTheme(appearance: appearance).secondaryText).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(17).harborGlass(appearance: appearance, radius: 19)
    }
}
