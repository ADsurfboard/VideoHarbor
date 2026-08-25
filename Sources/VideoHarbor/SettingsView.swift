import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct SettingsView: View {
    @ObservedObject var model: HarborAppModel
    var body: some View {
        let appearance = model.preferences.appearance
        let theme = HarborTheme(appearance: appearance)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HarborSectionHeader(
                    eyebrow: "Appearance / Privacy / Output",
                    title: "外观与偏好",
                    detail: "完整保留 WinHarbor 的三种材质、壁纸定制和动态节流。",
                    appearance: appearance
                )

                SettingsGroup(title: "窗口材质", icon: "circle.lefthalf.filled", appearance: appearance) {
                    HStack(spacing: 12) {
                        ForEach(HarborAppearance.allCases) { item in
                            Button { model.preferences.appearance = item } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: appearanceIcon(item)).foregroundStyle(item == model.preferences.appearance ? HarborPalette.seaGlass : theme.secondaryText)
                                        Spacer()
                                        if item == model.preferences.appearance { Image(systemName: "checkmark.circle.fill").foregroundStyle(HarborPalette.seaGlass) }
                                    }
                                    Text(item.displayName).font(.system(size: 13, weight: .semibold))
                                    Text(appearanceDetail(item)).font(.system(size: 9)).foregroundStyle(theme.secondaryText).multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                                .padding(14)
                                .background(item == model.preferences.appearance ? HarborPalette.seaGlass.opacity(0.09) : theme.sidebarTint.opacity(0.45), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(item == model.preferences.appearance ? HarborPalette.seaGlass.opacity(0.45) : theme.border, lineWidth: 0.7) }
                            }
                            .buttonStyle(HarborPressButtonStyle())
                        }
                    }
                }

                SettingsGroup(title: "壁纸与透明度", icon: "photo.on.rectangle.angled", appearance: appearance) {
                    HStack {
                        Button(action: model.useBuiltInWallpaper) { Label("雾港壁纸", systemImage: "water.waves") }
                            .buttonStyle(HarborActionButtonStyle(appearance: appearance, prominent: model.preferences.wallpaper.kind == .harbor))
                        Button(action: model.chooseWallpaper) { Label("导入图片或视频", systemImage: "plus") }
                            .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                        Spacer()
                        if model.preferences.wallpaper.kind != .harbor {
                            Text(model.preferences.wallpaper.kind == .video ? "VIDEO LOOP" : "STATIC IMAGE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(HarborPalette.seaGlass)
                        }
                    }
                    sliderRow("背景透明度", value: $model.preferences.wallpaper.transparency, range: 0...1, suffix: "%", scale: 100, appearance: appearance)
                    sliderRow("背景压暗", value: $model.preferences.wallpaper.dimming, range: 0...0.8, suffix: "%", scale: 100, appearance: appearance)
                    sliderRow("壁纸柔化", value: $model.preferences.wallpaper.blur, range: 0...18, suffix: "px", scale: 1, appearance: appearance)
                    sliderRow("窗口后景模糊", value: $model.preferences.wallpaper.backdropBlur, range: 0...48, suffix: "px", scale: 1, appearance: appearance)
                    Toggle("失焦、低电量或降低动态效果时暂停壁纸", isOn: $model.preferences.pauseBackgroundWhenInactive)
                        .font(.system(size: 11)).toggleStyle(.switch)
                }

                SettingsGroup(title: "下载默认值", icon: "arrow.down.circle", appearance: appearance) {
                    HStack(spacing: 18) {
                        Picker("清晰度", selection: $model.preferences.quality) {
                            ForEach(DownloadQuality.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("封装", selection: $model.preferences.container) {
                            ForEach(MediaContainer.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("浏览器 Cookie", selection: $model.preferences.cookieBrowser) {
                            ForEach(CookieBrowser.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("保存位置").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(theme.secondaryText)
                            Text(model.preferences.outputDirectory).font(.system(size: 10, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button(action: model.chooseOutputDirectory) { Label("更改", systemImage: "folder") }
                            .buttonStyle(HarborActionButtonStyle(appearance: appearance))
                    }
                    .padding(13).background(theme.sidebarTint.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                SettingsGroup(title: "Cookie 隐私", icon: "hand.raised.fill", appearance: appearance) {
                    Label("默认不读取 Cookie。启用后，yt-dlp 可能会读取所选浏览器的全部 Cookie 库，因此仅应在需要访问你已获授权的登录内容时开启。VideoHarbor 不导出、保存或上传 Cookie。", systemImage: "exclamationmark.shield")
                        .font(.system(size: 11)).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28).padding(.bottom, 20)
        }
    }

    private func appearanceIcon(_ item: HarborAppearance) -> String {
        switch item { case .dark: return "moon.fill"; case .light: return "sun.max.fill"; case .ultraClear: return "drop.fill" }
    }
    private func appearanceDetail(_ item: HarborAppearance) -> String {
        switch item { case .dark: return "高遮罩 regular glass"; case .light: return "浅雾与亮边缘"; case .ultraClear: return "macOS 26 clear glass" }
    }
    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        scale: Double,
        appearance: HarborAppearance
    ) -> some View {
        HStack {
            Text(title).font(.system(size: 11)).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range).tint(HarborPalette.seaGlass)
            Text("\(Int(value.wrappedValue * scale))\(suffix)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(HarborTheme(appearance: appearance).secondaryText).frame(width: 48, alignment: .trailing)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let appearance: HarborAppearance
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold))
            content
        }
        .padding(20).harborGlass(appearance: appearance)
    }
}
