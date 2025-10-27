//
//  CleanTimerView.swift
//  Dialed In
//
//  Alcove-inspired focus session timer with glass dial controls
//

import SwiftUI
import AppKit

struct CleanTimerView: View {
    let selectedApps: [AppItem]

    @State private var selectedMinutes: Double = 45
    @State private var isSessionActive = false
    @State private var remainingSeconds = Int(45 * 60)
    @State private var totalSeconds = Int(45 * 60)
    @State private var timer: Timer?
    @State private var showCompleteModal = false
    @State private var completedDurationMinutes = 0

    private let dialRange: ClosedRange<Double> = 5...180
    private let dialStep: Double = 5

    var body: some View {
        ZStack {
            mainContent

            if showCompleteModal {
                SessionCompleteModal(durationMinutes: completedDurationMinutes) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCompleteModal = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .onDisappear { timer?.invalidate() }
        .onChange(of: selectedMinutes) { _, newValue in
            guard !isSessionActive else { return }
            syncSeconds(with: newValue)
        }
    }

    private var mainContent: some View {
        VStack(spacing: Spacing.xxl) {
            if isSessionActive {
                activeSessionView
            } else {
                setupView
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.xxl)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isSessionActive)
    }

    // MARK: - Setup
    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xxl) {
                VStack(alignment: .center, spacing: Spacing.sm) {
                    Text("Dialed In Session")
                        .font(Typography.title)
                        .foregroundColor(Palette.textPrimary)

                    Text("Spin the dial to set how long you want to stay locked in.")
                        .font(Typography.body)
                        .foregroundColor(Palette.textSecondary)
                }

                FocusDial(
                    minutes: $selectedMinutes,
                    range: dialRange,
                    step: dialStep
                ) {
                    fireHaptic()
                }
                .frame(maxWidth: 360)
                .padding(.top, Spacing.lg)

                SessionStatGrid(
                    primary: SessionStatDescriptor(
                        title: "Focus Length",
                        value: verboseDuration(for: selectedMinutes),
                        icon: "timer",
                        accent: Palette.accent
                    ),
                    secondary: SessionStatDescriptor(
                        title: "Session Status",
                        value: appSummary,
                        icon: "lock.display",
                        accent: Palette.textSecondary
                    )
                )

                if !selectedApps.isEmpty {
                    SelectedAppsGlass(selectedApps: selectedApps)
                }

                PrimaryActionButton(
                    state: .startFocus,
                    isEnabled: !selectedApps.isEmpty
                ) {
                    startSession()
                }
                .padding(.top, Spacing.md)
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Active Session
    private var activeSessionView: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(alignment: .center, spacing: Spacing.sm) {
                Text("Stay locked in")
                    .font(Typography.title)
                    .foregroundColor(Palette.textPrimary)

                Text("Dialed In is blocking \(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s").")
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            CircularTimerView(
                totalSeconds: totalSeconds,
                remainingSeconds: remainingSeconds,
                isActive: true
            )
            .frame(maxWidth: 320)
            .padding(.top, Spacing.lg)

            SessionStatGrid(
                primary: SessionStatDescriptor(
                    title: "Time Remaining",
                    value: remainingSummary,
                    icon: "hourglass.circle.fill",
                    accent: Palette.accent
                ),
                secondary: SessionStatDescriptor(
                    title: "Finishes",
                    value: completionTimeDescription,
                    icon: "calendar.badge.clock",
                    accent: Palette.textSecondary
                )
            )

            SelectedAppsGlass(selectedApps: selectedApps)

            VStack(spacing: Spacing.md) {
                PrimaryActionButton(
                    state: .endSession,
                    isEnabled: true
                ) {
                    endSession()
                }

                Button {
                    addTime(minutes: 5)
                    fireHaptic()
                } label: {
                    Label("Add 5 minutes", systemImage: "plus.circle.fill")
                        .font(Typography.subheadline)
                        .foregroundColor(Palette.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.lg)
        }
    }

    // MARK: - Helpers
    private var appSummary: String {
        guard !selectedApps.isEmpty else { return "No apps selected" }
        if selectedApps.count == 1 {
            return "Locking \(selectedApps.first?.name ?? "")"
        }
        return "Locking \(selectedApps.count) apps"
    }

    private var remainingSummary: String {
        let minutesRemaining = max(remainingSeconds / 60, 0)
        return "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") left"
    }

    private var completionTimeDescription: String {
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Ends at \(formatter.string(from: endDate))"
    }

    private func verboseDuration(for minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let remaining = totalMinutes % 60

        switch (hours, remaining) {
        case (0, _):
            return "Focus for \(totalMinutes) minute\(totalMinutes == 1 ? "" : "s")"
        case (_, 0):
            return "Focus for \(hours) hour\(hours == 1 ? "" : "s")"
        default:
            return "Focus for \(hours)h \(remaining)m"
        }
    }

    private func fireHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func syncSeconds(with minutes: Double) {
        let seconds = Int(minutes * 60)
        totalSeconds = seconds
        remainingSeconds = seconds
    }

    private func startSession() {
        syncSeconds(with: selectedMinutes)
        isSessionActive = true
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                endSession(completed: true)
            }
        }
    }

    private func endSession(completed: Bool = false) {
        isSessionActive = false
        timer?.invalidate()
        timer = nil

        if completed {
            completedDurationMinutes = Int(selectedMinutes)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                showCompleteModal = true
            }
        }

        syncSeconds(with: selectedMinutes)
    }

    private func addTime(minutes: Int) {
        let secondsToAdd = minutes * 60
        remainingSeconds += secondsToAdd
        totalSeconds += secondsToAdd
        selectedMinutes = Double(totalSeconds) / 60.0
    }
}

// MARK: - Dial
struct FocusDial: View {
    @Binding var minutes: Double
    let range: ClosedRange<Double>
    let step: Double
    var onStep: (() -> Void)?

    @State private var lastStepIndex: Int = -1

    private var normalized: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return (minutes - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var dialAngle: Double { normalized * 360 }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * 0.12
            let innerSize = size - (lineWidth * 2.4)

            ZStack {
                // Tick marks
                Canvas { context, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let radius = min(canvasSize.width, canvasSize.height) / 2
                    let tickCount = Int((range.upperBound - range.lowerBound) / step) + 1

                    for index in 0..<tickCount {
                        let progress = Double(index) / Double(tickCount)
                        let angle = progress * (.pi * 2)
                        let outerPoint = CGPoint(
                            x: center.x + cos(angle - .pi / 2) * (radius - lineWidth / 2.8),
                            y: center.y + sin(angle - .pi / 2) * (radius - lineWidth / 2.8)
                        )
                        let innerPoint = CGPoint(
                            x: center.x + cos(angle - .pi / 2) * (radius - lineWidth * (index % 3 == 0 ? 1.1 : 1.6)),
                            y: center.y + sin(angle - .pi / 2) * (radius - lineWidth * (index % 3 == 0 ? 1.1 : 1.4))
                        )

                        var path = Path()
                        path.move(to: innerPoint)
                        path.addLine(to: outerPoint)

                        context.stroke(
                            path,
                            with: .color(Palette.textTertiary.opacity(index % 3 == 0 ? 0.8 : 0.4)),
                            lineWidth: index % 3 == 0 ? 2 : 1
                        )
                    }
                }

                // Base ring
                Circle()
                    .stroke(Palette.sidebarHighlight.opacity(0.4), lineWidth: lineWidth)

                // Active arc
                Circle()
                    .trim(from: 0, to: normalized)
                    .stroke(
                        AngularGradient(
                            colors: [Palette.accent, Palette.accentGlow, Palette.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.accentGlow.opacity(0.5), radius: 14, x: 0, y: 10)

                // Glow halo
                Circle()
                    .trim(from: 0, to: normalized)
                    .stroke(Palette.accent.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth * 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 18)

                // Center glass capsule with time readout
                VStack(spacing: Spacing.xs) {
                    Text(formattedHeroTime)
                        .font(Typography.heroMono)
                        .foregroundColor(Palette.textPrimary)

                    Text(verboseFocusLabel)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }
                .padding(Spacing.gutter)
                .frame(width: innerSize, height: innerSize)
                .background(
                    RoundedRectangle(cornerRadius: innerSize / 2, style: .continuous)
                        .fill(Palette.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: innerSize / 2, style: .continuous)
                                .stroke(Palette.glassStroke.opacity(0.8), lineWidth: 0.8)
                        )
                        .shadow(color: Palette.glassHighlight.opacity(0.35), radius: 24, x: 0, y: 16)
                )
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateDial(with: value.location, in: size)
                    }
                    .onEnded { _ in
                        lastStepIndex = Int((minutes - range.lowerBound) / step)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var formattedHeroTime: String {
        let totalSeconds = Int(minutes * 60)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, mins)
        } else {
            return String(format: "%02d", mins)
        }
    }

    private var verboseFocusLabel: String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let remaining = totalMinutes % 60

        if hours == 0 {
            return "minutes"
        } else if remaining == 0 {
            return "hours"
        } else {
            return "hours & minutes"
        }
    }

    private func updateDial(with location: CGPoint, in size: CGFloat) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        let distance = hypot(vector.dx, vector.dy)
        let radius = size / 2

        // Ignore drags near the centre to avoid accidental movements
        guard distance > radius * 0.35 else { return }

        var angle = atan2(vector.dy, vector.dx) + .pi / 2
        if angle < 0 { angle += .pi * 2 }

        let proportion = angle / (.pi * 2)
        let rawMinutes = range.lowerBound + proportion * (range.upperBound - range.lowerBound)
        let stepped = (rawMinutes / step).rounded() * step
        let clamped = min(max(stepped, range.lowerBound), range.upperBound)

        if clamped != minutes {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                minutes = clamped
            }
            let currentStepIndex = Int((clamped - range.lowerBound) / step)
            if currentStepIndex != lastStepIndex {
                lastStepIndex = currentStepIndex
                onStep?()
            }
        }
    }
}

// MARK: - Stats & Selections
struct SessionStatDescriptor {
    let title: String
    let value: String
    let icon: String
    let accent: Color
}

struct SessionStatGrid: View {
    let primary: SessionStatDescriptor
    let secondary: SessionStatDescriptor

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.lg) {
            SessionStatCard(
                title: primary.title,
                value: primary.value,
                icon: primary.icon,
                accent: primary.accent
            )

            SessionStatCard(
                title: secondary.title,
                value: secondary.value,
                icon: secondary.icon,
                accent: secondary.accent
            )
        }
    }
}

private struct SessionStatCard: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(Typography.headline)
                .foregroundColor(accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(Typography.micro)
                    .foregroundColor(Palette.textTertiary)

                Text(value)
                    .font(Typography.subheadline)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .alcoveCard(cornerRadius: 22, material: .menu, tint: Palette.sidebar, shadowRadius: 0, shadowOpacity: 0)
    }
}

private struct SelectedAppsGlass: View {
    let selectedApps: [AppItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Apps you'll keep open")
                .font(Typography.subheadline)
                .foregroundColor(Palette.textSecondary)

            if selectedApps.isEmpty {
                Text("Pick apps in the previous step to allow them during focus.")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textTertiary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: Spacing.sm)],
                    alignment: .leading,
                    spacing: Spacing.sm
                ) {
                    ForEach(selectedApps.prefix(10)) { app in
                        SessionAppBadge(app: app)
                    }

                    if selectedApps.count > 10 {
                        OverflowBadge(count: selectedApps.count - 10)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .alcoveCard(cornerRadius: 24, material: .menu, tint: Palette.sidebarHighlight, shadowRadius: 0, shadowOpacity: 0.05)
    }
}

private struct SessionAppBadge: View {
    let app: AppItem

    var body: some View {
        HStack(spacing: Spacing.xs) {
            appIcon
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                        .fill(Palette.sidebarHighlight.opacity(0.6))
                )

            Text(app.name)
                .font(Typography.caption)
                .foregroundColor(Palette.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.5))
        )
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous))
        } else {
            Image(systemName: app.fallbackSymbolName)
                .font(Typography.caption)
                .foregroundColor(Palette.accent)
        }
    }
}

private struct OverflowBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(Typography.caption)
            .foregroundColor(Palette.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(Palette.sidebarHighlight.opacity(0.4))
            )
    }
}

// MARK: - Flow Layout helper
struct CleanTimerView_Previews: PreviewProvider {
    static var previews: some View {
        CleanTimerView(selectedApps: Array(AppItem.sampleApps.prefix(6)))
            .frame(width: 700, height: 760)
            .background(Palette.windowTint)
            .preferredColorScheme(.dark)
    }
}
