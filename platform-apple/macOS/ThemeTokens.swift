// ThemeTokens.swift — adaptive Light/Dark surfaces, accessibility environment tokens,
// and macOS 26 Liquid Glass wrappers with macOS 14–15 material fallbacks.

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - User-Selectable Appearance Mode

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

// MARK: - Semantic Surface & Contrast Palette

enum DJTheme {
    static func workspaceBackground(
        for scheme: ColorScheme,
        reduceTransparency: Bool,
        highContrast: Bool
    ) -> LinearGradient {
        if scheme == .dark {
            if reduceTransparency || highContrast {
                let c = Color(red: 0.05, green: 0.06, blue: 0.09)
                return LinearGradient(colors: [c, c], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            return LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.07, green: 0.09, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Shaded cool slate-grey canvas in Light Mode so cards stand out clearly
            // without harsh, retina-glaring pure white backgrounds.
            if reduceTransparency || highContrast {
                let c = Color(red: 0.77, green: 0.80, blue: 0.85)
                return LinearGradient(colors: [c, c], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            return LinearGradient(
                colors: [
                    Color(red: 0.79, green: 0.82, blue: 0.87),
                    Color(red: 0.74, green: 0.78, blue: 0.84),
                    Color(red: 0.77, green: 0.80, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func contentCardFill(
        for scheme: ColorScheme,
        reduceTransparency: Bool,
        highContrast: Bool
    ) -> Color {
        if scheme == .dark {
            let base = Color(red: 0.11, green: 0.13, blue: 0.19)
            return base.opacity(reduceTransparency || highContrast ? 1.0 : 0.92)
        } else {
            // Soft off-white / warm paper surface rather than pure #FFFFFF glare.
            let base = Color(red: 0.945, green: 0.955, blue: 0.97)
            return base.opacity(reduceTransparency || highContrast ? 1.0 : 0.96)
        }
    }

    static func solidGlassFallbackFill(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.14, blue: 0.21)
            : Color(red: 0.90, green: 0.92, blue: 0.95)
    }

    static func topBarFrostTint(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.09, green: 0.11, blue: 0.16).opacity(0.22)
            : Color.white.opacity(0.18)
    }

    static func hairlineColor(
        for scheme: ColorScheme,
        baseOpacity: Double,
        highContrast: Bool
    ) -> Color {
        let boosted = highContrast ? min(0.75, baseOpacity * 2.2) : baseOpacity
        return scheme == .dark
            ? Color.white.opacity(boosted)
            : Color.black.opacity(min(0.45, boosted * 1.15))
    }

    static func pillFill(
        for scheme: ColorScheme,
        active: Bool = false,
        highContrast: Bool = false
    ) -> Color {
        if active { return Color.accentColor }
        let op = highContrast ? 0.16 : (scheme == .dark ? 0.10 : 0.08)
        return Color.primary.opacity(op)
    }

    static func glassSheenGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.03),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color.white.opacity(0.14),
                    Color.black.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Reduce Motion Helper

@MainActor
func djWithAnimation<Result>(
    _ reduceMotion: Bool,
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    if reduceMotion {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}

// MARK: - Liquid Glass Container & Capsule Modifiers (macOS 26+ with macOS 14–15 Fallback)

struct DJGlassContainer<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

private struct DJGlassCapsuleModifier: ViewModifier {
    var interactive: Bool
    var tint: Color?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let highContrast = (contrast == .increased)
        if reduceTransparency {
            content
                .background(
                    Capsule().fill(tint?.opacity(0.22) ?? DJTheme.solidGlassFallbackFill(for: colorScheme))
                )
                .overlay(
                    Capsule().strokeBorder(
                        DJTheme.hairlineColor(for: colorScheme, baseOpacity: 0.24, highContrast: highContrast),
                        lineWidth: highContrast ? 1.25 : 1
                    )
                )
        } else if #available(macOS 26, *) {
            let baseGlass: Glass = {
                var g = Glass.regular
                if let tint {
                    g = g.tint(tint)
                }
                if interactive {
                    g = g.interactive()
                }
                return g
            }()
            content
                .glassEffect(baseGlass, in: Capsule())
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(tint?.opacity(0.16) ?? Color.clear))
                )
                .overlay(
                    Capsule().strokeBorder(
                        DJTheme.hairlineColor(for: colorScheme, baseOpacity: 0.16, highContrast: highContrast),
                        lineWidth: 1
                    )
                )
        }
    }
}

private struct DJAccessibleControlModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let selected: Bool
    let isButton: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .modifier(OptionalHintModifier(hint: hint))
            .modifier(OptionalValueModifier(value: value))
            .modifier(OptionalTraitsModifier(selected: selected, isButton: isButton))
    }

    private struct OptionalHintModifier: ViewModifier {
        let hint: String?
        func body(content: Content) -> some View {
            if let hint, !hint.isEmpty {
                content.accessibilityHint(hint)
            } else {
                content
            }
        }
    }

    private struct OptionalValueModifier: ViewModifier {
        let value: String?
        func body(content: Content) -> some View {
            if let value, !value.isEmpty {
                content.accessibilityValue(value)
            } else {
                content
            }
        }
    }

    private struct OptionalTraitsModifier: ViewModifier {
        let selected: Bool
        let isButton: Bool
        func body(content: Content) -> some View {
            switch (selected, isButton) {
            case (true, true):   content.accessibilityAddTraits([.isSelected, .isButton])
            case (true, false):  content.accessibilityAddTraits(.isSelected)
            case (false, true):  content.accessibilityAddTraits(.isButton)
            case (false, false): content
            }
        }
    }
}

extension View {
    func djGlassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(DJGlassCapsuleModifier(interactive: interactive, tint: tint))
    }

    func djAccessibleControl(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        selected: Bool = false,
        isButton: Bool = false
    ) -> some View {
        modifier(
            DJAccessibleControlModifier(
                label: label,
                hint: hint,
                value: value,
                selected: selected,
                isButton: isButton
            )
        )
    }
}
