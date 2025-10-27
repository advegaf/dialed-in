import SwiftUI
import Combine
import AppKit

/// Centralised controller that owns the lifecycle of a focus session and enforces the allow-list.
@MainActor final class FocusSessionController: ObservableObject {
    @Published private(set) var isSessionActive = false
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var activeSessionApps: [AppItem] = []
    @Published private(set) var completedSessionMinutes: Int?
    @Published var blockedAppName: String?

    private var allowedBundleIDs: Set<String> = []
    private var timerCancellable: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var blockedResetWorkItem: DispatchWorkItem?
    private var lastActiveAllowedBundleID: String?

    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.WindowServer",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer",
        "com.apple.notificationcenterui"
    ]

    private let menuBarManager: MenuBarManager
    private let workspaceCenter = NSWorkspace.shared.notificationCenter

    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        registerMenuBarNotifications()
    }

    // MARK: - Session lifecycle

    func startSession(apps: [AppItem], durationMinutes: Double) {
        guard !apps.isEmpty else { return }

        if isSessionActive {
            endSession()
        }

        let seconds = max(1, Int(durationMinutes * 60))
        allowedBundleIDs = Set(apps.map { $0.bundleIdentifier }.filter { !$0.isEmpty })
        if let ownBundle = Bundle.main.bundleIdentifier {
            allowedBundleIDs.insert(ownBundle)
        }

        blockedResetWorkItem?.cancel()
        blockedAppName = nil
        completedSessionMinutes = nil

        activeSessionApps = apps
        totalSeconds = seconds
        remainingSeconds = seconds
        isSessionActive = true
        lastActiveAllowedBundleID = Bundle.main.bundleIdentifier

        menuBarManager.updateStatus(isActive: true, remainingSeconds: remainingSeconds)

        registerWorkspaceObservers()
        beginTimer()
        enforceCurrentFrontmostApplication()
        terminateDisallowedRunningApplications()
    }

    func endSession(completed: Bool = false) {
        guard isSessionActive else { return }

        timerCancellable?.cancel()
        timerCancellable = nil

        if completed {
            let elapsedSeconds = totalSeconds - remainingSeconds
            let minutes = max(1, Int(round(Double(elapsedSeconds) / 60.0)))
            completedSessionMinutes = minutes
        } else {
            completedSessionMinutes = nil
        }

        blockedResetWorkItem?.cancel()
        blockedResetWorkItem = nil
        blockedAppName = nil

        isSessionActive = false
        remainingSeconds = 0
        totalSeconds = 0
        activeSessionApps = []
        allowedBundleIDs.removeAll()
        lastActiveAllowedBundleID = nil

        menuBarManager.updateStatus(isActive: false)

        removeWorkspaceObservers()
    }

    func addTime(minutes: Int) {
        guard isSessionActive, minutes > 0 else { return }
        let additional = minutes * 60
        remainingSeconds += additional
        totalSeconds += additional
        menuBarManager.updateStatus(isActive: true, remainingSeconds: remainingSeconds)
    }

    func dismissCompletionSummary() {
        completedSessionMinutes = nil
    }

    // MARK: - Internal helpers

    private func beginTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.handleTimerTick()
            }
    }

    private func handleTimerTick() {
        guard isSessionActive else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
            menuBarManager.updateStatus(isActive: true, remainingSeconds: remainingSeconds)
        }

        if remainingSeconds <= 0 {
            endSession(completed: true)
        }
    }

    // MARK: - App enforcement

    private func registerWorkspaceObservers() {
        guard workspaceObservers.isEmpty else { return }

        let willLaunch = workspaceCenter.addObserver(forName: NSWorkspace.willLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleWorkspaceEvent(notification)
        }

        let didActivate = workspaceCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleWorkspaceEvent(notification)
        }

        workspaceObservers = [willLaunch, didActivate]
    }

    private func removeWorkspaceObservers() {
        for observer in workspaceObservers {
            workspaceCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func handleWorkspaceEvent(_ notification: Notification) {
        guard isSessionActive,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        if allowedBundleIDs.contains(bundleID) {
            lastActiveAllowedBundleID = bundleID
            return
        }

        block(application: app, bundleID: bundleID)
    }

    private func enforceCurrentFrontmostApplication() {
        guard isSessionActive,
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }

        if allowedBundleIDs.contains(bundleID) {
            lastActiveAllowedBundleID = bundleID
        } else {
            block(application: app, bundleID: bundleID)
        }
    }

    private func block(application: NSRunningApplication, bundleID: String) {
        let name = application.localizedName ?? bundleID
        triggerBlockedToast(for: name)
        ToastPresenter.shared.show(appName: name)

        if !application.isTerminated {
            application.forceTerminate()
        }

        focusLastAllowedApplication()
    }

    private func focusLastAllowedApplication() {
        if let bundleID = lastActiveAllowedBundleID,
           let allowedApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            allowedApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func triggerBlockedToast(for appName: String) {
        blockedResetWorkItem?.cancel()
        blockedAppName = appName

        let workItem = DispatchWorkItem { [weak self] in
            if self?.blockedAppName == appName {
                self?.blockedAppName = nil
            }
        }
        blockedResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func terminateDisallowedRunningApplications() {
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if allowedBundleIDs.contains(bundleID) { continue }
            if protectedBundleIdentifiers.contains(bundleID) { continue }
            if app == NSRunningApplication.current { continue }
            block(application: app, bundleID: bundleID)
        }
    }

    // MARK: - Menu bar integration

    private func registerMenuBarNotifications() {
        guard notificationObservers.isEmpty else { return }

        let addTimeObserver = NotificationCenter.default.addObserver(forName: .menuBarAddTime, object: nil, queue: .main) { [weak self] _ in
            self?.addTime(minutes: 5)
        }

        let endSessionObserver = NotificationCenter.default.addObserver(forName: .menuBarEndSession, object: nil, queue: .main) { [weak self] _ in
            self?.endSession()
        }

        notificationObservers = [addTimeObserver, endSessionObserver]
    }

}
