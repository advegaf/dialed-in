//
//  CircularTimerView.swift
//  Dialed In
//
//  Creative circular timer with glass ring and gradient progress
//

import SwiftUI

struct CircularTimerView: View {
    let totalSeconds: Int
    let remainingSeconds: Int
    let isActive: Bool

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let raw = Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        return min(max(raw, 0), 1)
    }

    private var formattedTime: String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var timeFont: Font {
        let hours = remainingSeconds / 3600
        switch hours {
        case 10...:
            return Font.system(size: 48, weight: .light).monospacedDigit()
        case 1...:
            return Font.system(size: 56, weight: .light).monospacedDigit()
        default:
            return Typography.heroMono
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let ringWidth = max(size * 0.12, 18)
            let innerSize = size - ringWidth * 2.6
            let haloGradient = RadialGradient(
                colors: [Palette.accent.opacity(0.22), Color.clear],
                center: .center,
                startRadius: innerSize / 2,
                endRadius: size / 1.1
            )

            ZStack {
                // Ambient halo
                Circle()
                    .fill(haloGradient)

                // Base ring with subtle blur
                Circle()
                    .stroke(Palette.sidebarHighlight.opacity(0.55), lineWidth: ringWidth)
                    .blur(radius: 1.5)

                // Tick marks
                ForEach(0..<120, id: \.self) { index in
                    let isMajor = index % 10 == 0
                    Capsule(style: .continuous)
                        .fill(Palette.textTertiary.opacity(isMajor ? 0.45 : 0.18))
                        .frame(width: isMajor ? 2.4 : 1.4, height: isMajor ? ringWidth * 0.9 : ringWidth * 0.6)
                        .offset(y: -(size / 2) + ringWidth * (isMajor ? 0.95 : 1.3))
                        .rotationEffect(.degrees(Double(index) / 120 * 360))
                }

                // Gradient progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Palette.accent, Palette.accentGlow, Palette.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.accentGlow.opacity(0.6), radius: 18, x: 0, y: 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)

                // Trailing glow for motion
                Circle()
                    .trim(from: max(progress - 0.03, 0), to: progress)
                    .stroke(Palette.accent.opacity(isActive ? 0.35 : 0.18), style: StrokeStyle(lineWidth: ringWidth * 1.4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 20)
                    .blendMode(.plusLighter)

                // Inner glass core
                VStack(spacing: Spacing.xs) {
                    Text(formattedTime)
                        .font(timeFont)
                        .foregroundColor(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(isActive ? "remaining" : "selected")
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
                .frame(width: innerSize, height: innerSize)
                .background(
                    RoundedRectangle(cornerRadius: innerSize / 2, style: .continuous)
                        .fill(Palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: innerSize / 2, style: .continuous)
                                .stroke(Palette.glassStroke.opacity(0.9), lineWidth: 0.8)
                        )
                        .shadow(color: Palette.glassHighlight.opacity(0.25), radius: 24, x: 0, y: 14)
                )
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus timer")
        .accessibilityValue("\(formattedTime) remaining")
        .accessibilityAddTraits(isActive ? [.updatesFrequently] : [])
    }
}

struct CircularTimerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xxl) {
            CircularTimerView(totalSeconds: 3600, remainingSeconds: 2400, isActive: true)
                .frame(width: 280, height: 280)
            CircularTimerView(totalSeconds: 3600, remainingSeconds: 900, isActive: false)
                .frame(width: 280, height: 280)
        }
        .padding()
        .background(Palette.windowTint)
        .preferredColorScheme(.dark)
    }
}
