import SwiftUI

struct SessionTemplateDraft {
    var id: UUID?
    var name: String = ""
    var appIDs: [String] = []
    var mode: FocusSessionMode = .allowList
    var durationMinutes: Int = 30

    var includeSchedule: Bool = false
    var scheduleFrequency: SessionTemplate.Schedule.Frequency = .once
    var scheduleTime: Date = Date()
    var selectedWeekdays: Set<Int> = []
    var reminderMinutes: Int = 0

    init() {}

    init(
        name: String,
        appIDs: [String],
        mode: FocusSessionMode,
        durationMinutes: Int,
        schedule: SessionTemplate.Schedule?
    ) {
        self.name = name
        self.appIDs = appIDs
        self.mode = mode
        self.durationMinutes = durationMinutes

        if let schedule {
            includeSchedule = true
            scheduleFrequency = schedule.frequency
            reminderMinutes = schedule.reminderMinutesBefore ?? 0
            selectedWeekdays = Set(schedule.weekdays ?? [])

            let calendar = Calendar.current
            if let date = calendar.date(from: schedule.time) {
                scheduleTime = date
            }
        } else {
            includeSchedule = false
        }
    }

    init(template: SessionTemplate) {
        self.init(
            name: template.name,
            appIDs: template.appIDs,
            mode: template.mode,
            durationMinutes: template.durationMinutes,
            schedule: template.schedule
        )
        id = template.id
    }

    mutating func replaceWithCurrent(appIDs: [String], mode: FocusSessionMode, durationMinutes: Int) {
        self.appIDs = appIDs
        self.mode = mode
        self.durationMinutes = durationMinutes
    }

    func makeTemplate() -> SessionTemplate {
        let schedule = includeSchedule ? makeSchedule() : nil
        return SessionTemplate(
            id: id ?? UUID(),
            name: name,
            appIDs: appIDs,
            mode: mode,
            durationMinutes: durationMinutes,
            schedule: schedule
        )
    }

    private func makeSchedule() -> SessionTemplate.Schedule? {
        let calendar = Calendar.current

        var components: DateComponents
        switch scheduleFrequency {
        case .once:
            components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduleTime)
        case .daily, .weekly:
            components = calendar.dateComponents([.hour, .minute], from: scheduleTime)
        }

        let weekdays: [Int]? = scheduleFrequency == .weekly ? Array(selectedWeekdays).sorted() : nil
        let reminder = reminderMinutes > 0 ? reminderMinutes : nil

        return SessionTemplate.Schedule(
            frequency: scheduleFrequency,
            time: components,
            weekdays: weekdays,
            reminderMinutesBefore: reminder
        )
    }
}

struct SessionTemplateEditorView: View {
    @Binding var draft: SessionTemplateDraft

    let isNew: Bool
    let appNames: [String]
    let canReplaceFromCurrent: Bool
    let onReplaceFromCurrent: (() -> Void)?
    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        let hasName = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let appsValid = draft.mode == .allowList ? !draft.appIDs.isEmpty : true
        let scheduleValid = !(draft.includeSchedule && draft.scheduleFrequency == .weekly && draft.selectedWeekdays.isEmpty)
        return hasName && appsValid && scheduleValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Template name", text: $draft.name)

                    Picker("Session mode", selection: $draft.mode) {
                        ForEach(FocusSessionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Stepper(value: $draft.durationMinutes, in: 5...180, step: 5) {
                        Text("Duration \(draft.durationMinutes) min")
                    }
                }

                Section("Apps Captured") {
                    Label(
                        draft.mode == .allowList ?
                            "\(draft.appIDs.count) app\(draft.appIDs.count == 1 ? "" : "s") allowed" :
                            "\(draft.appIDs.count) app\(draft.appIDs.count == 1 ? "" : "s") blocked",
                        systemImage: "app.badge"
                    )

                    if !appNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(appNames, id: \.self) { name in
                                    Text(name)
                                        .font(Typography.caption)
                                        .foregroundColor(Palette.textSecondary)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Palette.sidebarHighlight.opacity(0.6))
                                        )
                                }
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    } else {
                        Text("Apps will mirror your current selection.")
                            .font(Typography.caption)
                            .foregroundColor(Palette.textTertiary)
                    }

                    if let onReplaceFromCurrent, canReplaceFromCurrent {
                        Button("Use current selection") {
                            onReplaceFromCurrent()
                        }
                    }
                }

                Section("Schedule") {
                    Toggle("Schedule automatically", isOn: $draft.includeSchedule.animation())

                    if draft.includeSchedule {
                        Picker("Frequency", selection: $draft.scheduleFrequency) {
                            ForEach(SessionTemplate.Schedule.Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }

                        if draft.scheduleFrequency == .once {
                            DatePicker("Date & time", selection: $draft.scheduleTime, displayedComponents: [.date, .hourAndMinute])
                        } else {
                            DatePicker("Start time", selection: $draft.scheduleTime, displayedComponents: [.hourAndMinute])
                        }

                        if draft.scheduleFrequency == .weekly {
                            WeekdayPicker(selectedWeekdays: $draft.selectedWeekdays)
                        }

                        Stepper(value: $draft.reminderMinutes, in: 0...120, step: 5) {
                            if draft.reminderMinutes == 0 {
                                Text("No reminder")
                            } else {
                                Text("Reminder \(draft.reminderMinutes) min before")
                            }
                        }
                    }
                }

                if draft.mode == .allowList && draft.appIDs.isEmpty {
                    Text("Allow List templates must include at least one app. Replace with the current selection before saving.")
                        .font(Typography.caption)
                        .foregroundColor(.red)
                }

                if draft.includeSchedule && draft.scheduleFrequency == .weekly && draft.selectedWeekdays.isEmpty {
                    Text("Pick at least one weekday for the schedule.")
                        .font(Typography.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle(isNew ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }
}

private struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Int>

    private let weekdays = Calendar.current.shortWeekdaySymbols.enumerated().map { ($0.offset + 1, $0.element) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Weekdays")
                .font(Typography.caption)
                .foregroundColor(Palette.textSecondary)

            HStack(spacing: Spacing.sm) {
                ForEach(weekdays, id: \.0) { index, symbol in
                    Button {
                        toggle(index)
                    } label: {
                        Text(symbol.uppercased())
                            .font(Typography.caption)
                            .fontWeight(selectedWeekdays.contains(index) ? .semibold : .regular)
                            .foregroundColor(selectedWeekdays.contains(index) ? Palette.accent : Palette.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedWeekdays.contains(index) ? Palette.accent.opacity(0.18) : Palette.sidebarHighlight.opacity(0.4))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func toggle(_ index: Int) {
        if selectedWeekdays.contains(index) {
            selectedWeekdays.remove(index)
        } else {
            selectedWeekdays.insert(index)
        }
    }
}
