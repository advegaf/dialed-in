import Foundation
import Combine
import UserNotifications
import AppKit

final class SessionTemplateScheduler {
    private let templateStore: SessionTemplateStore
    private unowned let sessionController: FocusSessionController
    private var cancellables: Set<AnyCancellable> = []
    private var activeTimers: [UUID: Timer] = [:]
    private var scheduledReminderIdentifiers: Set<String> = []
    private let notificationCenter = UNUserNotificationCenter.current()
    private var hasRequestedNotificationAuthorization = false

    init(templateStore: SessionTemplateStore, sessionController: FocusSessionController) {
        self.templateStore = templateStore
        self.sessionController = sessionController

        templateStore.$templates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSchedules()
            }
            .store(in: &cancellables)

        DispatchQueue.main.async {
            self.refreshSchedules()
        }
    }
}

// MARK: - Scheduling

private extension SessionTemplateScheduler {
    func refreshSchedules() {
        cancelAllTimers()
        removePendingReminders()

        for template in templateStore.templates {
            guard template.schedule != nil else { continue }
            schedule(template: template)
        }
    }

    func schedule(template: SessionTemplate) {
        guard let schedule = template.schedule,
              let fireDate = nextFireDate(for: schedule) else {
            return
        }

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.handleTrigger(for: template.id)
        }
        RunLoop.main.add(timer, forMode: .common)
        activeTimers[template.id] = timer

        if let reminderMinutes = schedule.reminderMinutesBefore, reminderMinutes > 0 {
            scheduleReminder(for: template, fireDate: fireDate, minutesBefore: reminderMinutes)
        }
    }

    func handleTrigger(for templateID: UUID) {
        activeTimers[templateID]?.invalidate()
        activeTimers[templateID] = nil

        guard let template = templateStore.template(withID: templateID),
              let templateSchedule = template.schedule else {
            return
        }

        Task { @MainActor in
            if !sessionController.isSessionActive {
                let appItems = buildAppItems(for: template)
                sessionController.startSession(template: template, availableApps: appItems)
            }
        }

        // Schedule next occurrence for recurring templates
        if templateSchedule.frequency != .once {
            schedule(template: template)
        }
    }

    func buildAppItems(for template: SessionTemplate) -> [AppItem] {
        template.appIDs.compactMap { bundleID in
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               let bundle = Bundle(url: url) {
                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return AppItem(
                    name: displayName,
                    bundleIdentifier: bundleID,
                    icon: icon,
                    bundleURL: url,
                    isSelected: true
                )
            } else {
                return AppItem(
                    name: bundleID,
                    bundleIdentifier: bundleID,
                    icon: nil,
                    bundleURL: nil,
                    isSelected: true
                )
            }
        }
    }

    func nextFireDate(for schedule: SessionTemplate.Schedule) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch schedule.frequency {
        case .once:
            guard let date = calendar.date(from: schedule.time), date > now else { return nil }
            return date
        case .daily:
            var components = schedule.time
            components.year = calendar.component(.year, from: now)
            components.month = calendar.component(.month, from: now)
            components.day = calendar.component(.day, from: now)
            if let today = calendar.date(from: components), today > now {
                return today
            }
            return calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components) ?? now)
        case .weekly:
            guard let weekdays = schedule.weekdays, !weekdays.isEmpty else { return nil }
            let orderedWeekdays = weekdays.sorted()

            for offset in 0..<14 {
                guard let candidate = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: candidate)
                if orderedWeekdays.contains(weekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: candidate)
                    components.hour = schedule.time.hour
                    components.minute = schedule.time.minute
                    if let date = calendar.date(from: components), date > now {
                        return date
                    }
                }
            }
            return nil
        }
    }
}

// MARK: - Reminders

private extension SessionTemplateScheduler {
    func scheduleReminder(for template: SessionTemplate, fireDate: Date, minutesBefore: Int) {
        let reminderDate = fireDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard reminderDate > Date() else { return }

        requestNotificationAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Focus Session"
        content.body = "\"\(template.name)\" starts in \(minutesBefore) minute\(minutesBefore == 1 ? "" : "s")."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "template.\(template.id.uuidString).reminder"
        scheduledReminderIdentifiers.insert(identifier)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request, withCompletionHandler: nil)
    }

    func requestNotificationAuthorizationIfNeeded() {
        guard !hasRequestedNotificationAuthorization else { return }
        hasRequestedNotificationAuthorization = true

        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Intentionally ignored; we best-effort schedule reminders.
        }
    }
}

// MARK: - Cleanup helpers

private extension SessionTemplateScheduler {
    func cancelAllTimers() {
        activeTimers.values.forEach { $0.invalidate() }
        activeTimers.removeAll()
    }

    func removePendingReminders() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(scheduledReminderIdentifiers))
        scheduledReminderIdentifiers.removeAll()
    }
}
