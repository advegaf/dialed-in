//
//  TimerSessionView.swift
//  Dialed In
//
//  Session timer surface styled after Alcove with template management
//

import SwiftUI
import AppKit

struct TimerSessionView: View {
    @EnvironmentObject private var sessionController: FocusSessionController
    @EnvironmentObject private var templateStore: SessionTemplateStore
    @AppStorage("dialedIn.sessionMode") private var sessionModeRawValue: String = FocusSessionMode.allowList.rawValue
    @AppStorage("dialedIn.focusSelectedMinutes") private var storedFocusMinutes: Double = 30

    @Binding var apps: [AppItem]

    @State private var selectedMinutes: Double = 30
    @State private var hasSyncedStoredMinutes = false

    @State private var isTemplateEditorPresented = false
    @State private var templateDraft = SessionTemplateDraft()
    @State private var editingTemplateID: UUID?
    @State private var templateToDelete: SessionTemplate?
    @State private var isShowingDeleteConfirmation = false
    @State private var templateErrorMessage: String?

    private var isSessionActive: Bool { sessionController.isSessionActive }
    private var remainingSeconds: Int { sessionController.remainingSeconds }
    private var totalSeconds: Int { sessionController.totalSeconds }
    private var activeSessionApps: [AppItem] { sessionController.activeSessionApps }

    private var selectedApps: [AppItem] {
        apps.filter { $0.isSelected }
    }

    private var selectedAppIDs: [String] {
        selectedApps.map { $0.id }
    }

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

    private var activeTitle: String {
        sessionMode == .allowList ? "Stay locked in" : "Stay distraction free"
    }

    private var activeSubtitle: String {
        let count = activeSessionApps.count
        switch sessionMode {
        case .allowList:
            return count == 0 ? "All other apps remain blocked." : "Dialed In is keeping \(count) app\(count == 1 ? "" : "s") available."
        case .blockList:
            return count == 0 ? "No apps are blocked this session." : "Dialed In is blocking \(count) app\(count == 1 ? "" : "s")."
        }
    }

    private var canCreateTemplateFromCurrent: Bool {
        sessionMode == .allowList ? !selectedApps.isEmpty : true
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
            syncInitialMinutes()
        }
        .onChange(of: selectedMinutes) { _, newValue in
            if !isSessionActive {
                storedFocusMinutes = newValue
            }
        }
        .sheet(isPresented: $isTemplateEditorPresented) {
            SessionTemplateEditorView(
                draft: $templateDraft,
                isNew: editingTemplateID == nil,
                appNames: templateAppNames(for: templateDraft.appIDs),
                canReplaceFromCurrent: canCreateTemplateFromCurrent,
                onReplaceFromCurrent: {
                    templateDraft.replaceWithCurrent(
                        appIDs: selectedAppIDs,
                        mode: sessionMode,
                        durationMinutes: Int(selectedMinutes.rounded())
                    )
                },
                onCancel: { isTemplateEditorPresented = false },
                onSave: { saveTemplateDraft() }
            )
        }
        .confirmationDialog(
            "Delete Template?",
            isPresented: $isShowingDeleteConfirmation,
            presenting: templateToDelete
        ) { template in
            Button("Delete \"\(template.name)\"", role: .destructive) {
                templateStore.remove(template)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Unable to Save Template", isPresented: Binding(
            get: { templateErrorMessage != nil },
            set: { if !$0 { templateErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(templateErrorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Layout Sections

private extension TimerSessionView {
    var header: some View {
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

    var setupContent: some View {
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
                SelectedAppsPanel(selectedApps: selectedApps, onRemove: { _ in }, mode: sessionMode)
                    .frame(maxWidth: .infinity)
            }

            historySection

            templatesSection(isInteractive: true)

            PrimaryActionButton(
                state: buttonState,
                isEnabled: sessionMode == .allowList ? !selectedApps.isEmpty : true
            ) {
                toggleSession()
            }
        }
        .frame(maxWidth: .infinity)
    }

    var activeSessionContent: some View {
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

            templatesSection(isInteractive: false)

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

    @ViewBuilder
    func templatesSection(isInteractive: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Session Templates")
                    .font(Typography.headline)
                    .foregroundColor(Palette.textPrimary)

                Spacer()

                Button {
                    presentTemplateEditor(for: nil)
                } label: {
                    Label("Save current setup", systemImage: "plus")
                        .font(Typography.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(!isInteractive || !canCreateTemplateFromCurrent)
            }

            if templateStore.templates.isEmpty {
                templateEmptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(templateStore.templates) { template in
                        templateRow(for: template, isInteractive: isInteractive)

                        if template.id != templateStore.templates.last?.id {
                            Divider().overlay(Palette.divider)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Palette.sidebarHighlight.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(Palette.divider.opacity(0.25), lineWidth: 0.8)
                        )
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Palette.divider.opacity(0.3), lineWidth: 0.8)
                )
        )
        .overlay {
            if !isInteractive {
                Color.black.opacity(0.2)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
                    .overlay(
                        Text("Pause your session to manage templates.")
                            .font(Typography.caption)
                            .foregroundColor(Palette.textSecondary)
                            .padding(Spacing.md),
                        alignment: .center
                    )
            }
        }
    }

    var templateEmptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Palette.textSecondary)
            Text("No saved templates yet")
                .font(Typography.body)
                .foregroundColor(Palette.textSecondary)
            Text("Capture the current selection, duration, and focus mode for quick reuse.")
                .font(Typography.caption)
                .foregroundColor(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    @ViewBuilder
    func templateRow(for template: SessionTemplate, isInteractive: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(Typography.body)
                        .foregroundColor(Palette.textPrimary)
                    Text(templateSummary(template))
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.sm) {
                    Button {
                        configure(using: template)
                    } label: {
                        Label("Apply", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.accent)
                    .disabled(!isInteractive)

                    Button {
                        start(template: template)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Palette.accent)
                    .disabled(!isInteractive || !canStart(template: template))
                }
            }

            HStack(spacing: Spacing.md) {
                if let schedule = template.schedule {
                    Label(scheduleSummary(schedule), systemImage: "clock.badge.checkmark")
                        .font(Typography.caption)
                        .foregroundColor(Palette.textTertiary)
                }

                Spacer()

                Menu {
                    Button("Edit") {
                        presentTemplateEditor(for: template)
                    }

                    Button("Duplicate") {
                        duplicate(template)
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        templateToDelete = template
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                }
                .menuStyle(.button)
                .disabled(!isInteractive)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    var historySection: some View {
        if !sessionController.sessionHistory.isEmpty {
            SessionHistoryView(records: sessionController.sessionHistory)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Template Management

private extension TimerSessionView {
    func presentTemplateEditor(for template: SessionTemplate?) {
        if let template {
            editingTemplateID = template.id
            templateDraft = SessionTemplateDraft(template: template)
        } else {
            editingTemplateID = nil
            templateDraft = SessionTemplateDraft(
                name: defaultTemplateName(),
                appIDs: selectedAppIDs,
                mode: sessionMode,
                durationMinutes: Int(selectedMinutes.rounded()),
                schedule: nil
            )
        }
        isTemplateEditorPresented = true
    }

    func saveTemplateDraft() {
        guard !templateDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            templateErrorMessage = "Give your template a name before saving."
            return
        }

        if templateDraft.mode == .allowList && templateDraft.appIDs.isEmpty {
            templateErrorMessage = "Allow List templates must include at least one app."
            return
        }

        if templateDraft.includeSchedule && templateDraft.scheduleFrequency == .weekly && templateDraft.selectedWeekdays.isEmpty {
            templateErrorMessage = "Choose at least one weekday for a weekly schedule."
            return
        }

        let template = templateDraft.makeTemplate()

        if let editingTemplateID {
            templateStore.update(template.replacingID(with: editingTemplateID))
        } else {
            templateStore.add(template)
        }

        isTemplateEditorPresented = false
    }

    func configure(using template: SessionTemplate) {
        let clamped = min(max(template.durationMinutes, 5), 180)
        selectedMinutes = Double(clamped)
        sessionModeRawValue = template.mode.rawValue
        setSelectedAppIDs(Set(template.appIDs))
        storedFocusMinutes = selectedMinutes
    }

    func start(template: SessionTemplate) {
        guard canStart(template: template) else { return }
        configure(using: template)
        sessionController.startSession(template: template, availableApps: apps)
    }

    func duplicate(_ template: SessionTemplate) {
        var copy = template
        copy = copy.replacingID(with: UUID())
        copy.name = "\(template.name) Copy"
        templateStore.add(copy)
    }

    func canStart(template: SessionTemplate) -> Bool {
        if template.mode == .allowList {
            return !template.appIDs.isEmpty
        }
        return true
    }

    func setSelectedAppIDs(_ ids: Set<String>) {
        for index in apps.indices {
            apps[index].isSelected = ids.contains(apps[index].id)
        }
    }

    func templateAppNames(for ids: [String]) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.name) })
        return ids.compactMap { lookup[$0] }
    }

    func defaultTemplateName() -> String {
        let base = "Focus Template"
        let existingNames = Set(templateStore.templates.map { $0.name })
        if !existingNames.contains(base) {
            return base
        }
        for index in 2...1000 {
            let candidate = "\(base) \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }
        return "\(base) \(Int.random(in: 1001...9999))"
    }
}

// MARK: - Stats & helpers

private extension TimerSessionView {
    func syncInitialMinutes() {
        if !hasSyncedStoredMinutes && !isSessionActive {
            selectedMinutes = storedFocusMinutes
            hasSyncedStoredMinutes = true
        }
    }

    func statGrid(primary: SessionStatDescriptor, secondary: SessionStatDescriptor) -> some View {
        SessionStatGrid(primary: primary, secondary: secondary)
            .frame(maxWidth: .infinity)
    }

    var primaryStatDescription: SessionStatDescriptor {
        SessionStatDescriptor(
            title: "Focus Length",
            value: verboseDuration(Int(selectedMinutes)),
            icon: "timer",
            accent: Palette.accent
        )
    }

    var secondaryStatDescription: SessionStatDescriptor {
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

    var activePrimaryStat: SessionStatDescriptor {
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

    var activeSecondaryStat: SessionStatDescriptor {
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

    var remainingSummary: String {
        let minutesRemaining = max(remainingSeconds / 60, 0)
        return "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") left"
    }

    func templateSummary(_ template: SessionTemplate) -> String {
        var parts: [String] = []
        parts.append("\(template.durationMinutes) min")
        let modeLabel = template.mode == .allowList ? "allow" : "block"
        parts.append("\(template.appIDs.count) \(modeLabel) app\(template.appIDs.count == 1 ? "" : "s")")
        if let schedule = template.schedule {
            parts.append(scheduleShortDescription(schedule))
        }
        return parts.joined(separator: " • ")
    }

    func scheduleSummary(_ schedule: SessionTemplate.Schedule) -> String {
        switch schedule.frequency {
        case .once:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            if let date = Calendar.current.date(from: schedule.time) {
                return "Runs once \(formatter.string(from: date))"
            }
            return "Runs once"
        case .daily:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            if let date = Calendar.current.date(from: schedule.time) {
                return "Daily at \(formatter.string(from: date))"
            }
            return "Daily schedule"
        case .weekly:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let weekdayNames = schedule.weekdays?
                .sorted()
                .compactMap { weekdaySymbols[$0] }
                .joined(separator: ", ") ?? "Selected days"
            if let date = Calendar.current.date(from: schedule.time) {
                return "Weekly (\(weekdayNames)) at \(formatter.string(from: date))"
            }
            return "Weekly (\(weekdayNames))"
        }
    }

    func scheduleShortDescription(_ schedule: SessionTemplate.Schedule) -> String {
        switch schedule.frequency {
        case .once:
            return "One-time"
        case .daily:
            return "Daily"
        case .weekly:
            let weekdayNames = schedule.weekdays?
                .sorted()
                .compactMap { weekdayShortSymbols[$0] }
                .joined(separator: ", ") ?? "Weekly"
            return "Weekly \(weekdayNames)"
        }
    }

    func toggleSession() {
        if isSessionActive {
            sessionController.endSession()
        } else {
            Task { @MainActor in
                presentStartSessionPrompt()
            }
        }
    }

    func presentStartSessionPrompt() {
        if sessionMode == .allowList && selectedApps.isEmpty {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Start Focus Session?"
        alert.informativeText = "You are about to start a new focus session. Quit distracting apps before you begin?"
        alert.addButton(withTitle: "Terminate & Start")
        alert.addButton(withTitle: "Start Without Terminating")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            beginSession(terminateDistractions: true)
        case .alertSecondButtonReturn:
            beginSession(terminateDistractions: false)
        default:
            break
        }
    }

    func beginSession(terminateDistractions: Bool) {
        guard sessionMode != .allowList || !selectedApps.isEmpty else { return }

        sessionController.startSession(apps: selectedApps, mode: sessionMode, durationMinutes: selectedMinutes)

        if terminateDistractions {
            sessionController.minimizeDistractions()
        }
    }

    func verboseDuration(_ minutes: Int) -> String {
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

private let weekdaySymbols: [Int: String] = {
    let symbols = Calendar.current.weekdaySymbols
    var map: [Int: String] = [:]
    for (index, symbol) in symbols.enumerated() {
        map[index + 1] = symbol
    }
    return map
}()

private let weekdayShortSymbols: [Int: String] = {
    let symbols = Calendar.current.shortWeekdaySymbols
    var map: [Int: String] = [:]
    for (index, symbol) in symbols.enumerated() {
        map[index + 1] = symbol
    }
    return map
}()

private extension SessionTemplate {
    func replacingID(with newID: UUID) -> SessionTemplate {
        SessionTemplate(
            id: newID,
            name: name,
            appIDs: appIDs,
            mode: mode,
            durationMinutes: durationMinutes,
            schedule: schedule
        )
    }
}

// MARK: - Scheduling helpers

// MARK: - Previews

struct TimerSessionView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var apps = AppItem.sampleApps
        @StateObject private var templateStore = SessionTemplateStore()
        @StateObject private var sessionController: FocusSessionController

        init() {
            let menuBarManager = MenuBarManager()
            let controller = FocusSessionController(menuBarManager: menuBarManager)
            _sessionController = StateObject(wrappedValue: controller)
        }

        var body: some View {
            TimerSessionView(apps: $apps)
                .environmentObject(sessionController)
                .environmentObject(templateStore)
                .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .frame(width: 960, height: 680)
    }
}
