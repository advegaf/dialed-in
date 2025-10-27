//
//  TimerSessionView.swift
//  Dialed In
//
//  Session timer surface styled after Alcove
//

import SwiftUI

struct TimerSessionView: View {
    @EnvironmentObject private var sessionController: FocusSessionController

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
                Text("Session Timer")
                    .font(Typography.largeTitle)
                    .foregroundColor(Palette.textPrimary)

                Text("Dialed In keeps you locked into the apps you approved for this focus session.")
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()
        }
    }

    private var setupContent: some View {
        VStack(spacing: Spacing.xxl) {
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
                SelectedAppsPanel(selectedApps: selectedApps, onRemove: { _ in })
                    .frame(maxWidth: .infinity)
            }

            PrimaryActionButton(
                state: buttonState,
                isEnabled: !selectedApps.isEmpty
            ) {
                toggleSession()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeSessionContent: some View {
        VStack(spacing: Spacing.xxl) {
            HStack {
                Spacer()
                CircularTimerView(totalSeconds: totalSeconds, remainingSeconds: remainingSeconds, isActive: true)
                    .frame(width: 320, height: 320)
                Spacer()
            }

            statGrid(primary: activePrimaryStat, secondary: activeSecondaryStat)

            if !activeSessionApps.isEmpty {
                SelectedAppsPanel(selectedApps: activeSessionApps, onRemove: { _ in })
                    .frame(maxWidth: .infinity)
            }

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
        SessionStatDescriptor(
            title: "Apps Allowed",
            value: selectedApps.isEmpty ? "No apps selected" : "\(selectedApps.count) apps",
            icon: "lock.display", accent: Palette.textSecondary
        )
    }

    private var activePrimaryStat: SessionStatDescriptor {
        let minutesRemaining = max(remainingSeconds / 60, 0)
        return SessionStatDescriptor(
            title: "Time Remaining",
            value: "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") left",
            icon: "hourglass.circle.fill",
            accent: Palette.accent
        )
    }

    private var activeSecondaryStat: SessionStatDescriptor {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        return SessionStatDescriptor(
            title: "Finishes",
            value: formatter.string(from: endDate),
            icon: "calendar.badge.clock",
            accent: Palette.textSecondary
        )
    }

    private func toggleSession() {
        if isSessionActive {
            sessionController.endSession()
        } else {
            sessionController.startSession(apps: selectedApps, durationMinutes: selectedMinutes)
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
