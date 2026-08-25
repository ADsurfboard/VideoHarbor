import AppKit
import AVFoundation
import QuartzCore
import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

struct HarborWallpaperView: View {
    let settings: WallpaperSettings
    let appearance: HarborAppearance
    let pauseWhenInactive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isAnimating: Bool {
        !reduceMotion
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && (!pauseWhenInactive || scenePhase == .active)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AdjustableBackdropBlur(radius: settings.backdropBlur)
                matteBackdrop.opacity(1 - clampedTransparency)
                ZStack {
                    switch settings.kind {
                    case .harbor: HarborAmbientWallpaper(appearance: appearance, isAnimating: isAnimating)
                    case .image: staticWallpaper
                    case .video: videoWallpaper
                    }
                    overlayColor.opacity(settings.dimming)
                }
                .scaleEffect(1 + min(settings.blur, 18) / 420)
                .blur(radius: settings.blur)
                .opacity(wallpaperOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder private var staticWallpaper: some View {
        if let path = settings.filePath, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image).resizable().scaledToFill().ignoresSafeArea()
        } else {
            HarborAmbientWallpaper(appearance: appearance, isAnimating: isAnimating)
        }
    }

    @ViewBuilder private var videoWallpaper: some View {
        if let path = settings.filePath, FileManager.default.fileExists(atPath: path) {
            LoopingVideoView(url: URL(fileURLWithPath: path), isPlaying: isAnimating)
                .ignoresSafeArea()
        } else {
            HarborAmbientWallpaper(appearance: appearance, isAnimating: isAnimating)
        }
    }

    private var overlayColor: Color {
        appearance == .light ? .white : HarborPalette.night
    }

    private var wallpaperOpacity: Double {
        let userOpacity = 1 - clampedTransparency
        switch (settings.kind, appearance) {
        case (.harbor, _): return userOpacity
        case (_, .dark): return 0.85 * userOpacity
        case (_, .light): return 0.75 * userOpacity
        case (_, .ultraClear): return 0.6 * userOpacity
        }
    }

    private var clampedTransparency: Double { max(0, min(1, settings.transparency)) }

    private var matteBackdrop: some View {
        LinearGradient(
            colors: {
                switch appearance {
                case .dark: return [Color(hex: 0x11191E), Color(hex: 0x27363B)]
                case .light: return [Color(hex: 0xEEF3F2), Color(hex: 0xC9D6D5)]
                case .ultraClear: return [Color(hex: 0x19262C), Color(hex: 0x3D4B50)]
                }
            }(),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AdjustableBackdropBlur: NSViewRepresentable {
    let radius: Double
    func makeNSView(context: Context) -> BackdropBlurHostView {
        let view = BackdropBlurHostView()
        view.update(radius: radius)
        return view
    }
    func updateNSView(_ nsView: BackdropBlurHostView, context: Context) { nsView.update(radius: radius) }
}

final class BackdropBlurHostView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .underWindowBackground
        blendingMode = .behindWindow
        state = .active
        isEmphasized = false
    }
    required init?(coder: NSCoder) { nil }
    func update(radius: Double) {
        let clamped = max(0, min(48, radius))
        isHidden = clamped <= 0.05
        alphaValue = min(1, clamped / 40)
    }
}

struct HarborAmbientWallpaper: View {
    let appearance: HarborAppearance
    let isAnimating: Bool
    @State private var drifting = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: appearance == .light
                        ? [.white.opacity(0.34), Color(hex: 0xB7CED0).opacity(0.22), Color(hex: 0xE8E2D9).opacity(0.2)]
                        : [Color(hex: 0x071014).opacity(appearance == .ultraClear ? 0.1 : 0.28), Color(hex: 0x10252C).opacity(0.18), Color(hex: 0x1E2830).opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(HarborPalette.seaGlass.opacity(appearance == .light ? 0.08 : 0.12))
                    .frame(width: geometry.size.width * 0.72)
                    .blur(radius: 118)
                    .drawingGroup(opaque: false, colorMode: .linear)
                    .offset(x: drifting ? geometry.size.width * 0.12 : -geometry.size.width * 0.12, y: -geometry.size.height * 0.31)
                Circle()
                    .fill(HarborPalette.oxide.opacity(appearance == .light ? 0.07 : 0.1))
                    .frame(width: geometry.size.width * 0.5)
                    .blur(radius: 132)
                    .drawingGroup(opaque: false, colorMode: .linear)
                    .offset(x: geometry.size.width * 0.28, y: drifting ? geometry.size.height * 0.15 : -geometry.size.height * 0.15)
            }
        }
        .onAppear { updateAnimation(isAnimating) }
        .onChange(of: isAnimating) { _, active in updateAnimation(active) }
    }

    private func updateAnimation(_ active: Bool) {
        if active {
            withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: true)) { drifting = true }
        } else {
            withAnimation(.easeOut(duration: 0.25)) { drifting = false }
        }
    }
}

struct LoopingVideoView: NSViewRepresentable {
    let url: URL
    let isPlaying: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        context.coordinator.configure(url: url, surface: view)
        context.coordinator.setPlaying(isPlaying)
        return view
    }
    func updateNSView(_ nsView: VideoSurfaceView, context: Context) {
        if context.coordinator.currentURL != url { context.coordinator.configure(url: url, surface: nsView) }
        context.coordinator.setPlaying(isPlaying)
    }
    static func dismantleNSView(_ nsView: VideoSurfaceView, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var currentURL: URL?
        func configure(url: URL, surface: VideoSurfaceView) {
            stop()
            currentURL = url
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
            player = queue
            surface.playerLayer.player = queue
            surface.playerLayer.videoGravity = .resizeAspectFill
        }
        func setPlaying(_ playing: Bool) { playing ? player?.play() : player?.pause() }
        func stop() { player?.pause(); player?.removeAllItems(); player = nil; looper = nil; currentURL = nil }
        deinit { stop() }
    }
}

final class VideoSurfaceView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); wantsLayer = true; layer = playerLayer }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); playerLayer.frame = bounds }
}
