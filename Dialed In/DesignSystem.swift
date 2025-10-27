//
//  DesignSystem.swift
//  Dialed In
//
//  Alcove-inspired macOS design tokens
//

import SwiftUI

// MARK: - Typography
enum Typography {
    // SF Pro Display/Text - Alcove aesthetic
    static let largeTitle = Font.system(size: 32, weight: .semibold)
    static let title = Font.system(size: 22, weight: .semibold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let subheadline = Font.system(size: 15, weight: .medium)
    static let body = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 11, weight: .medium)
    static let micro = Font.system(size: 10, weight: .medium)
    static let heroMono = Font.system(size: 72, weight: .light).monospacedDigit()
}

// MARK: - Palette
enum Palette {
    // Background tints
    static let windowTop = Color.black.opacity(0.38)
    static let windowBottom = Color.black.opacity(0.58)
    static let windowTint = Color.black.opacity(0.32)
    static let windowHighlight = Color.white.opacity(0.08)
    static let sidebar = Color.white.opacity(0.05)
    static let sidebarHighlight = Color.white.opacity(0.08)
    static let card = Color.white.opacity(0.10)
    static let cardElevated = Color.white.opacity(0.14)

    // Glass accents
    static let glassTint = Color.white.opacity(0.12)
    static let glassStroke = Color.white.opacity(0.18)
    static let glassHighlight = Color.white.opacity(0.35)

    // Accent & semantic colors
    static let accent = Color(hex: "44E0C4")
    static let accentGlow = Color(hex: "4DF5D6")
    static let danger = Color(hex: "FF453A")

    // Typography colors
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.45)
    static let divider = Color.white.opacity(0.10)
}

// MARK: - Layout metrics
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let gutter: CGFloat = 32
}

enum CornerRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let pill: CGFloat = 22
    static let button: CGFloat = 14
}

enum Shadow {
    static let soft = Color.black.opacity(0.45)
}

// MARK: - Helpers
extension Color {
    // Legacy aliases for backwards compatibility while we modernize views
    static var appBackground: Color { Palette.windowTop }
    static var contentBackground: Color { Palette.card }
    static var accent: Color { Palette.accent }
    static var textPrimary: Color { Palette.textPrimary }
    static var textSecondary: Color { Palette.textSecondary }
    static var textTertiary: Color { Palette.textTertiary }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
extension View {
    func alcoveCard(
        cornerRadius: CGFloat = CornerRadius.md,
        material: NSVisualEffectView.Material = .hudWindow,
        tint: Color = Palette.glassTint,
        shadowRadius: CGFloat = 18,
        shadowOpacity: Double = 0.18
    ) -> some View {
        background(
            GlassBackground(
                material: material,
                tint: tint,
                stroke: Palette.glassStroke,
                highlight: Palette.glassHighlight,
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                shadowOpacity: shadowOpacity
            )
        )
    }

    func glowingAccentBorder(cornerRadius: CGFloat = CornerRadius.sm) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Palette.accent, Palette.accentGlow.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }
}

// MARK: - Glass Components
struct GlassBackground: View {
    let material: NSVisualEffectView.Material
    let tint: Color
    let stroke: Color
    let highlight: Color
    let cornerRadius: CGFloat
    var shadowRadius: CGFloat = 18
    var shadowOpacity: Double = 0.18

    var body: some View {
        VisualEffectBlur(material: material, blendingMode: .withinWindow)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 0.9)
            )
            .shadow(color: Shadow.soft.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 24)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(highlight.opacity(0.2), lineWidth: 0.4)
                    .blendMode(.plusLighter)
            )
    }
}

// Visual Effect Blur for macOS materials
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
