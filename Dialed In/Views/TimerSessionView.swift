//
//  TimerSessionView.swift
//  Dialed In
//
//  Session timer surface styled after Alcove
//

import SwiftUI
import AppKit

struct TimerSessionView: View {
    @EnvironmentObject private var sessionController: FocusSessionController
    @AppStorage("dialedIn.sessionMode") private var sessionModeRawValue: String = FocusSessionMode.allowList.rawValue

    @AppStorage("dialedIn.focusSelectedMinutes") private var storedFocusMinutes: Double = 30
    @State private var selectedMinutes: Double = 30
    @State private var hasSyncedStoredMinutes = false

    let selectedApps: [AppItem]

    private var isSessionActive: Bool { sessionController.isSessionActive }
    private var remainingSeconds: Int { sessionController.remainingSeconds }
    private var totalSeconds: Int { sessionController.totalSeconds }
    private var activeSessionApps: [AppItem] { sessionController.activeSessionApps }

    private var buttonState: ActionButtonState {
        isSessionActive ? .endSession : .startFocus
    }

    private var sessionMode: FocusSessionMode {
        FocusSessionMode(rawValue: sessionModeRawValue) ?? .allowList
    }

    private var headerTitle: String { "Session Timer" }

    private var headerSubtitle: String {
        switch sessionMode {
        case .allowList:
            return "Dialed In blocks everything except the apps you approve for this session."
        case .blockList:
            return "Dialed In blocks only the apps you select while leaving everything else open."
        }
    }

    private var setupTitle: String {
        sessionMode == .allowList ? "Dialed In Session" : "Create a block session"
    }

    private var setupSubtitle: String {
        sessionMode == .allowList
            ? "Spin the dial to choose how long your allowed apps stay open."
            : "Choose how long Dialed In should keep those distractions closed."
    }

    private var activeTitle: String {
        sessionMode == .allowList ? "Stay locked in" : "Stay distraction free"
    }

    private var activeSubtitle: String {
        let count = activeSessionApps.count
        switch sessionMode {
        case .allowList:
            if count == 0 {
                return "All other apps remain blocked."
            }
            return "Dialed In is keeping \(count) app\(count == 1 ? "" : "s") available."
        case .blockList:
            if count == 0 {
                return "No apps are blocked this session."
            }
            return "Dialed In is blocking \(count) app\(count == 1 ? "" : "s")."
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Palette.divider.opacity(0.25), lineWidth: 0.8)
                )

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    header
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Spacing.lg)

                    if isSessionActive {
                        activeSessionContent
                    } else {
                        setupContent
                    }
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 44)
                .padding(.vertical, 36)
            }

            if let completedMinutes = sessionController.completedSessionMinutes {
                SessionCompleteModal(durationMinutes: completedMinutes) {
                    sessionController.dismissCompletionSummary()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            if !hasSyncedStoredMinutes && !isSessionActive {
                selectedMinutes = storedFocusMinutes
                hasSyncedStoredMinutes = true
            }
        }
        .onChange(of: selectedMinutes) { _, newValue in
            if !isSessionActive {
                storedFocusMinutes = newValue
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.55))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Palette.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(Typography.largeTitle)
                    .foregroundColor(Palette.textPrimary)

                Text(headerSubtitle)
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()
        }
    }

    private var setupContent: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.sm) {
                Text(setupTitle)
                    .font(Typography.title)
                    .foregroundColor(Palette.textPrimary)
                Text(setupSubtitle)
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            HStack {
                Spacer()
                FocusDial(
                    minutes: $selectedMinutes,
                    range: 5...180,
                    step: 5
                ) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                .frame(width: 360, height: 360)
                Spacer()
            }

            statGrid(primary: primaryStatDescription, secondary: secondaryStatDescription)

            if !selectedApps.isEmpty {
                SelectedAppsPanel(selectedApps: selectedApps, onRemove: { _ in }, mode: sessionMode)
                    .frame(maxWidth: .infinity)
            }

            historySection

            PrimaryActionButton(
                state: buttonState,
                isEnabled: sessionMode == .allowList ? !selectedApps.isEmpty : true
            ) {
                toggleSession()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeSessionContent: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.sm) {
                Text(activeTitle)
                    .font(Typography.title)
                    .foregroundColor(Palette.textPrimary)
                Text(activeSubtitle)
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            HStack {
                Spacer()
                CircularTimerView(totalSeconds: totalSeconds, remainingSeconds: remainingSeconds, isActive: true)
                    .frame(width: 320, height: 320)
                Spacer()
            }

            statGrid(primary: activePrimaryStat, secondary: activeSecondaryStat)

            if !activeSessionApps.isEmpty {
                SelectedAppsPanel(selectedApps: activeSessionApps, onRemove: { _ in }, mode: sessionMode)
                    .frame(maxWidth: .infinity)
            }

            historySection

            VStack(spacing: Spacing.md) {
                PrimaryActionButton(state: .endSession, isEnabled: true) {
                    sessionController.endSession()
                }

                Button {
                    sessionController.addTime(minutes: 5)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } label: {
                    Label("Add 5 minutes", systemImage: "plus.circle.fill")
                        .font(Typography.subheadline)
                        .foregroundColor(Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statGrid(primary: SessionStatDescriptor, secondary: SessionStatDescriptor) -> some View {
        SessionStatGrid(primary: primary, secondary: secondary)
            .frame(maxWidth: .infinity)
    }

    private var primaryStatDescription: SessionStatDescriptor {
        SessionStatDescriptor(
            title: "Focus Length",
            value: verboseDuration(Int(selectedMinutes)),
            icon: "timer", accent: Palette.accent
        )
    }

    private var secondaryStatDescription: SessionStatDescriptor {
        let title = sessionMode == .allowList ? "Apps Allowed" : "Apps Blocked"
        let icon = sessionMode == .allowList ? "lock.display" : "nosign"
        let value: String
        if selectedApps.isEmpty {
            value = sessionMode == .allowList ? "No apps selected" : "No apps blocked"
        } else {
            value = "\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s")"
        }
        return SessionStatDescriptor(
            title: title,
            value: value,
            icon: icon,
            accent: Palette.textSecondary
        )
    }

    private var activePrimaryStat: SessionStatDescriptor {
        let minutesRemaining = max(remainingSeconds / 60, 0)
        let title = sessionMode == .allowList ? "Time Remaining" : "Focus Ends"
        let icon = sessionMode == .allowList ? "hourglass.circle.fill" : "lock.slash"
        let value = sessionMode == .allowList
            ? "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") left"
            : remainingSummary
        return SessionStatDescriptor(
            title: title,
            value: value,
            icon: icon,
            accent: Palette.accent
        )
    }

    private var activeSecondaryStat: SessionStatDescriptor {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let title = sessionMode == .allowList ? "Finishes" : "Unlocked"
        return SessionStatDescriptor(
            title: title,
            value: formatter.string(from: endDate),
            icon: "calendar.badge.clock",
            accent: Palette.textSecondary
        )
    }

    private var remainingSummary: String {
        let minutesRemaining = max(remainingSeconds / 60, 0)
        return "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") left"
    }

    private func toggleSession() {
        if isSessionActive {
            sessionController.endSession()
        } else {
            Task { @MainActor in
                presentStartSessionPrompt()
            }
        }
    }

    private func verboseDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _):
            return "Focus for \(minutes) minute\(minutes == 1 ? "" : "s")"
        case (_, 0):
            return "Focus for \(hours) hour\(hours == 1 ? "" : "s")"
        default:
            return "Focus for \(hours)h \(remainder)m"
        }
    }
}

struct TimerSessionView_Previews: PreviewProvider {
    static var previews: some View {
        let menuBarManager = MenuBarManager()
        let sessionController = FocusSessionController(menuBarManager: menuBarManager)

        return TimerSessionView(selectedApps: Array(AppItem.sampleApps.prefix(4)))
            .environmentObject(sessionController)
            .preferredColorScheme(.dark)
    }
}
