import SwiftUI

struct HarborRootView: View {
    @ObservedObject var model: HarborAppModel

    var body: some View {
        let appearance = model.preferences.appearance
        let theme = HarborTheme(appearance: appearance)
        ZStack {
            HarborWallpaperView(
                settings: model.preferences.wallpaper,
                appearance: appearance,
                pauseWhenInactive: model.preferences.pauseBackgroundWhenInactive
            )
            HStack(spacing: 0) {
                HarborSidebar(model: model)
                VStack(spacing: 0) {
                    topBar(theme: theme)
                    Group {
                        switch model.selectedSection {
                        case .extract: ExtractView(model: model)
                        case .downloads: DownloadsView(model: model)
                        case .toolchain: ToolchainView(model: model)
                        case .settings: SettingsView(model: model)
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                }
            }
            WindowConfigurator().frame(width: 0, height: 0)
            if let toast = model.toastMessage {
                VStack { Spacer(); HStack { Spacer(); HarborToast(message: toast, appearance: appearance).onTapGesture { model.dismissToast() } } }
                    .padding(22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(3.2))
                        await MainActor.run { model.dismissToast() }
                    }
            }
        }
        .buttonStyle(HarborPressButtonStyle())
        .foregroundStyle(theme.primaryText)
        .preferredColorScheme(appearance == .light ? .light : .dark)
        .alert("VideoHarbor", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("知道了") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func topBar(theme: HarborTheme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sectionTitle).font(.system(size: 13, weight: .semibold))
                Text(sectionSubtitle).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(theme.secondaryText)
            }
            Spacer()
            PipelineSpineView(model: model)
            Spacer()
            HarborStatusPill(
                title: model.toolchain.isReady ? "原始源流就绪" : "工具链待修复",
                color: model.toolchain.isReady ? HarborPalette.seaGlass : HarborPalette.amber
            )
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
        .background(theme.sidebarTint.opacity(0.55)).background(WindowDragRegion())
    }

    private var sectionTitle: String {
        switch model.selectedSection {
        case .extract: return "链接提取"
        case .downloads: return "下载船坞"
        case .toolchain: return "提取工具链"
        case .settings: return "外观与偏好"
        }
    }

    private var sectionSubtitle: String {
        switch model.selectedSection {
        case .extract: return "DOUYIN / BILIBILI / YOUTUBE / TIKTOK"
        case .downloads: return "\(model.activeCount) ACTIVE / \(model.completedCount) COMPLETED"
        case .toolchain: return model.toolchain.isReady ? "YT-DLP / FFMPEG READY" : "MISSING COMPONENTS"
        case .settings: return model.preferences.appearance.rawValue.uppercased()
        }
    }
}
