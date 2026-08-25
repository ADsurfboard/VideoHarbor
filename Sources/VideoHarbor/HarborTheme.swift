import SwiftUI
#if canImport(VideoHarborCore)
import VideoHarborCore
#endif

enum HarborPalette {
    static let night = Color(hex: 0x0B1318)
    static let nightRaised = Color(hex: 0x14242B)
    static let fog = Color(hex: 0xEDF3F2)
    static let oxide = Color(hex: 0x39788C)
    static let amber = Color(hex: 0xF0A33B)
    static let copper = Color(hex: 0xB96F4B)
    static let seaGlass = Color(hex: 0x84C7C3)
}

struct HarborTheme {
    let appearance: HarborAppearance

    var primaryText: Color {
        appearance == .light ? HarborPalette.night : HarborPalette.fog
    }

    var secondaryText: Color { primaryText.opacity(0.62) }

    var sidebarTint: Color {
        switch appearance {
        case .dark: return HarborPalette.night.opacity(0.4)
        case .light: return Color.white.opacity(0.38)
        case .ultraClear: return HarborPalette.night.opacity(0.08)
        }
    }

    var glassTint: Color? {
        switch appearance {
        case .dark: return HarborPalette.nightRaised.opacity(0.2)
        case .light: return Color.white.opacity(0.18)
        case .ultraClear: return nil
        }
    }

    var border: Color {
        appearance == .light
            ? Color.white.opacity(0.5)
            : HarborPalette.fog.opacity(appearance == .ultraClear ? 0.24 : 0.16)
    }

    var shadow: Color {
        appearance == .light ? Color.black.opacity(0.08) : Color.black.opacity(0.22)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct HarborGlassModifier: ViewModifier {
    let appearance: HarborAppearance
    let radius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let theme = HarborTheme(appearance: appearance)
        if #available(macOS 26.0, *) {
            switch appearance {
            case .ultraClear:
                content
                    .glassEffect(.clear.interactive(interactive), in: shape)
                    .overlay(shape.stroke(theme.border, lineWidth: 0.7))
                    .shadow(color: theme.shadow, radius: 22, y: 12)
            case .dark, .light:
                content
                    .glassEffect(
                        .regular.tint(theme.glassTint).interactive(interactive),
                        in: shape
                    )
                    .overlay(shape.stroke(theme.border, lineWidth: 0.7))
                    .shadow(color: theme.shadow, radius: 20, y: 10)
            }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(theme.border, lineWidth: 0.7))
                .shadow(color: theme.shadow, radius: 18, y: 9)
        }
    }
}

extension View {
    func harborGlass(
        appearance: HarborAppearance,
        radius: CGFloat = 22,
        interactive: Bool = false
    ) -> some View {
        modifier(HarborGlassModifier(
            appearance: appearance,
            radius: radius,
            interactive: interactive
        ))
    }
}

struct HarborActionButtonStyle: ButtonStyle {
    let appearance: HarborAppearance
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let theme = HarborTheme(appearance: appearance)
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : theme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                if prominent {
                    Capsule().fill(LinearGradient(
                        colors: [HarborPalette.oxide, Color(hex: 0x275A6B)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                } else {
                    Capsule().fill(theme.sidebarTint)
                }
            }
            .overlay {
                Capsule().stroke(
                    prominent ? HarborPalette.seaGlass.opacity(0.35) : theme.border,
                    lineWidth: 0.7
                )
            }
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 0.98 : 0.85) : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 2.5 : 0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.48)
            .animation(
                configuration.isPressed || reduceMotion
                    ? .easeOut(duration: 0.07)
                    : .spring(response: 0.38, dampingFraction: 0.44, blendDuration: 0.08),
                value: configuration.isPressed
            )
    }
}

struct HarborPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.85
    var pressedOffset: CGFloat = 2.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 0.98 : pressedScale) : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? pressedOffset : 0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.48)
            .animation(
                configuration.isPressed || reduceMotion
                    ? .easeOut(duration: 0.07)
                    : .spring(response: 0.38, dampingFraction: 0.44, blendDuration: 0.08),
                value: configuration.isPressed
            )
    }
}
