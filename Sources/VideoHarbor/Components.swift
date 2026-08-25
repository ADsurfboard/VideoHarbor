import AppKit
import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

enum HarborBuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }
    static var architecture: String {
        #if arch(arm64)
        return "ARM64"
        #else
        return "X86_64"
        #endif
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.toolbarStyle = .unifiedCompact
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        if !window.styleMask.contains(.fullScreen),
           let visible = window.screen?.visibleFrame,
           window.frame.width > visible.width || window.frame.height > visible.height {
            window.setContentSize(NSSize(width: min(1120, visible.width - 80), height: min(760, visible.height - 80)))
            window.center()
        }
    }
}

struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragSurfaceView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DragSurfaceView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

struct HarborSidebar: View {
    @ObservedObject var model: HarborAppModel
    private let entries: [(HarborSection, String, String)] = [
        (.extract, "提取", "arrow.down.doc.fill"),
        (.downloads, "下载", "tray.full.fill"),
        (.toolchain, "工具链", "gearshape.2.fill"),
        (.settings, "设置", "slider.horizontal.3")
    ]

    var body: some View {
        let theme = HarborTheme(appearance: model.preferences.appearance)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFill().frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 0.7) }
                    .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("VideoHarbor").font(.system(size: 16, weight: .semibold, design: .serif))
                    Text("流港 · \(HarborBuildInfo.version)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 14)

            ForEach(entries, id: \.0) { entry in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { model.selectedSection = entry.0 }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: entry.2).font(.system(size: 14, weight: .semibold)).frame(width: 22)
                        Text(entry.1).font(.system(size: 13, weight: .medium))
                        Spacer()
                        if badge(for: entry.0) > 0 {
                            Text("\(badge(for: entry.0))")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(theme.sidebarTint, in: Capsule())
                        }
                    }
                    .foregroundStyle(model.selectedSection == entry.0 ? theme.primaryText : theme.secondaryText)
                    .padding(.horizontal, 12).frame(height: 42)
                    .background {
                        if model.selectedSection == entry.0 {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(theme.sidebarTint)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(HarborPalette.seaGlass).frame(width: 3, height: 20).offset(x: -1)
                                }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HarborPressButtonStyle())
            }
            Spacer()
            Button { model.selectedSection = .toolchain } label: {
                SystemMiniStatus(
                    title: "提取内核",
                    value: model.toolchain.isReady ? "就绪" : "待修复",
                    color: model.toolchain.isReady ? HarborPalette.seaGlass : HarborPalette.amber
                )
                .padding(13)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .harborGlass(appearance: model.preferences.appearance, radius: 20, interactive: true)
            }
            .buttonStyle(HarborPressButtonStyle())
        }
        .padding(16).frame(width: 210)
        .foregroundStyle(theme.primaryText)
        .background(theme.sidebarTint)
    }

    private func badge(for section: HarborSection) -> Int {
        switch section {
        case .downloads: return model.activeCount
        case .toolchain: return model.toolchain.missingTools.count
        default: return 0
        }
    }
}

struct SystemMiniStatus: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7).shadow(color: color.opacity(0.5), radius: 5)
            Text(title).font(.system(size: 10, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 9, weight: .semibold, design: .monospaced)).opacity(0.66)
        }
    }
}

struct PipelineSpineView: View {
    @ObservedObject var model: HarborAppModel
    @State private var pulse = false
    private let nodes = [
        ("LINK", "link"),
        ("RESOLVE", "sparkle.magnifyingglass"),
        ("SOURCE", "film.stack.fill"),
        ("FILE", "doc.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(color(for: index).opacity(0.18)).frame(width: 25, height: 25)
                        Image(systemName: node.1).font(.system(size: 10, weight: .bold)).foregroundStyle(color(for: index))
                    }
                    Text(node.0).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color(for: index))
                }
                if index < nodes.count - 1 {
                    Rectangle()
                        .fill(LinearGradient(colors: [color(for: index).opacity(0.7), color(for: index + 1).opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 24, height: 1)
                        .overlay {
                            if model.isResolving || model.activeCount > 0 {
                                Circle().fill(HarborPalette.amber).frame(width: 4, height: 4).offset(x: pulse ? 10 : -10)
                            }
                        }
                }
            }
        }
        .onAppear { withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { pulse = true } }
    }

    private func color(for index: Int) -> Color {
        let inactive = model.preferences.appearance == .light ? Color(hex: 0x3F6068) : HarborPalette.fog.opacity(0.72)
        switch index {
        case 0: return model.shareText.isEmpty ? inactive : HarborPalette.seaGlass
        case 1: return model.isResolving ? HarborPalette.amber : (model.preview == nil ? inactive : HarborPalette.seaGlass)
        case 2: return model.preview == nil ? inactive : HarborPalette.oxide
        default: return model.completedCount > 0 ? HarborPalette.seaGlass : inactive
        }
    }
}

struct HarborSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String
    let appearance: HarborAppearance
    var body: some View {
        let theme = HarborTheme(appearance: appearance)
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(HarborPalette.seaGlass)
            Text(title).font(.system(size: 31, weight: .semibold, design: .serif)).foregroundStyle(theme.primaryText)
            Text(detail).font(.system(size: 13)).foregroundStyle(theme.secondaryText)
        }
    }
}

struct HarborStatusPill: View {
    let title: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule()).foregroundStyle(color)
    }
}

struct HarborToast: View {
    let message: String
    let appearance: HarborAppearance
    var body: some View {
        let theme = HarborTheme(appearance: appearance)
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(HarborPalette.seaGlass)
            Text(message).font(.system(size: 11, weight: .medium)).lineLimit(3)
        }
        .foregroundStyle(theme.primaryText).padding(.horizontal, 16).padding(.vertical, 11)
        .harborGlass(appearance: appearance, radius: 16)
    }
}

struct HarborEmptyState: View {
    let icon: String
    let title: String
    let detail: String
    let appearance: HarborAppearance
    var body: some View {
        let theme = HarborTheme(appearance: appearance)
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(HarborPalette.seaGlass)
            Text(title).font(.system(size: 17, weight: .semibold, design: .serif))
            Text(detail).font(.system(size: 12)).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center).frame(maxWidth: 380)
        }
        .foregroundStyle(theme.primaryText).frame(maxWidth: .infinity, minHeight: 240).padding(28)
        .harborGlass(appearance: appearance)
    }
}

extension Double {
    var harborDuration: String {
        let seconds = max(0, Int(self.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension Int64 {
    var harborBytes: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}
