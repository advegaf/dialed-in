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
    @Published private(set) var sessionHistory: [SessionRecord] = []

    private var allowedBundleIDs: Set<String> = []
    private var timerCancellable: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var blockedResetWorkItem: DispatchWorkItem?
    private var lastActiveAllowedBundleID: String?
    private var sessionStartDate: Date?
    private var disableWhileFullscreen = UserDefaults.standard.bool(forKey: "dialedIn.disableWhileFullscreen")

    private var sessionMode: FocusSessionMode = .allowList
    private var blockedBundleIDs: Set<String> = []

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
    private let historyStore = SessionHistoryStore(cloudSyncManager: CloudSyncManager.shared)

    init(menuBarManager: MenuBarManager) {
        self.menuBarManager = menuBarManager
        sessionHistory = historyStore.load()
        registerMenuBarNotifications()
        registerForCloudHistoryUpdates()
    }

    // MARK: - Session lifecycle

    func startSession(apps: [AppItem], mode: FocusSessionMode, durationMinutes: Double) {
        if isSessionActive {
            endSession()
        }

        let seconds = max(1, Int(durationMinutes * 60))
        sessionMode = mode

        switch mode {
        case .allowList:
            guard !apps.isEmpty else { return }
            allowedBundleIDs = Set(apps.map { $0.bundleIdentifier }.filter { !$0.isEmpty })
            if let ownBundle = Bundle.main.bundleIdentifier {
                allowedBundleIDs.insert(ownBundle)
            }
            allowedBundleIDs.formUnion(protectedBundleIdentifiers)
            blockedBundleIDs = []
        case .blockList:
            blockedBundleIDs = Set(apps.map { $0.bundleIdentifier }.filter { !$0.isEmpty })
            blockedBundleIDs.subtract(protectedBundleIdentifiers)
            allowedBundleIDs = []
            if let ownBundle = Bundle.main.bundleIdentifier {
                allowedBundleIDs.insert(ownBundle)
            }
            allowedBundleIDs.formUnion(protectedBundleIdentifiers)
        }

        blockedResetWorkItem?.cancel()
        blockedAppName = nil
        completedSessionMinutes = nil
        sessionStartDate = Date()

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

        let sessionApps = activeSessionApps
        let completedMode = sessionMode

        if completed {
            let elapsedSeconds = totalSeconds - remainingSeconds
            let minutes = max(1, Int(round(Double(elapsedSeconds) / 60.0)))
            completedSessionMinutes = minutes
            let record = SessionRecord(
                id: UUID(),
                startedAt: sessionStartDate ?? Date().addingTimeInterval(-Double(totalSeconds)),
                durationMinutes: minutes,
                mode: completedMode,
                appNames: sessionApps.map { $0.name }
            )
            sessionHistory.insert(record, at: 0)
            historyStore.save(sessionHistory)
        } else {
            completedSessionMinutes = nil
        }

        blockedResetWorkItem?.cancel()
        blockedResetWorkItem = nil
        blockedAppName = nil

        sessionStartDate = nil

        isSessionActive = false
        remainingSeconds = 0
        totalSeconds = 0
        activeSessionApps = []
        allowedBundleIDs.removeAll()
        lastActiveAllowedBundleID = nil

        menuBarManager.updateStatus(isActive: false)

        removeWorkspaceObservers()

        blockedBundleIDs.removeAll()
        sessionMode = .allowList
    }

    func addTime(minutes: Int) {
        guard isSessionActive, minutes > 0 else { return }
        let additional = minutes * 60
        remainingSeconds += additional
        totalSeconds += additional
        menuBarManager.updateStatus(isActive: true, remainingSeconds: remainingSeconds)
    }

    func setDisableWhileFullscreen(_ value: Bool) {
        disableWhileFullscreen = value
        guard isSessionActive else { return }

        if value {
            // When bypassing enforcement begins, allow the active fullscreen app to remain focused.
            if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                lastActiveAllowedBundleID = bundleID
            }
        } else {
            enforceCurrentFrontmostApplication()
            terminateDisallowedRunningApplications()
        }
    }

    func dismissCompletionSummary() {
        completedSessionMinutes = nil
    }

    func synchronizeHistoryWithCloudIfEnabled() {
        historyStore.save(sessionHistory)
    }

    func importSessionHistoryFromCloud(_ records: [SessionRecord]) {
        sessionHistory = historyStore.merge(with: records)
    }

    func startSession(template: SessionTemplate, availableApps: [AppItem]) {
        let idSet = Set(template.appIDs)
        let appsToUse = availableApps.filter { idSet.contains($0.id) }

        if template.mode == .allowList && appsToUse.isEmpty {
            return
        }

        startSession(
            apps: appsToUse,
            mode: template.mode,
            durationMinutes: Double(template.durationMinutes)
        )
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

        let didLaunch = workspaceCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleWorkspaceEvent(notification)
        }

        let didActivate = workspaceCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleWorkspaceEvent(notification)
        }

        let didUnhide = workspaceCenter.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleWorkspaceEvent(notification)
        }

        let activeSpaceChanged = workspaceCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSpaceChange()
        }

        workspaceObservers = [willLaunch, didLaunch, didActivate, didUnhide, activeSpaceChanged]
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

        if shouldBypassEnforcementForFullscreen() {
            lastActiveAllowedBundleID = bundleID
            return
        }

        if sessionMode == .blockList {
            if blockedBundleIDs.contains(bundleID) {
                block(application: app, bundleID: bundleID)
            } else {
                lastActiveAllowedBundleID = bundleID
            }
            return
        }

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

        if shouldBypassEnforcementForFullscreen() {
            lastActiveAllowedBundleID = bundleID
            return
        }

        if allowedBundleIDs.contains(bundleID) {
            lastActiveAllowedBundleID = bundleID
        } else {
            block(application: app, bundleID: bundleID)
        }
    }

    private func handleSpaceChange() {
        guard isSessionActive else { return }
        if shouldBypassEnforcementForFullscreen() { return }
        enforceCurrentFrontmostApplication()
        terminateDisallowedRunningApplications()
    }

    private func block(application: NSRunningApplication, bundleID: String) {
        if shouldBypassEnforcementForFullscreen() {
            lastActiveAllowedBundleID = bundleID
            return
        }

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
        if shouldBypassEnforcementForFullscreen() { return }

        switch sessionMode {
        case .allowList:
            for app in NSWorkspace.shared.runningApplications {
                guard let bundleID = app.bundleIdentifier else { continue }
                if allowedBundleIDs.contains(bundleID) { continue }
                if protectedBundleIdentifiers.contains(bundleID) { continue }
                if app == NSRunningApplication.current { continue }
                block(application: app, bundleID: bundleID)
            }
        case .blockList:
            for app in NSWorkspace.shared.runningApplications {
                guard let bundleID = app.bundleIdentifier else { continue }
                if !blockedBundleIDs.contains(bundleID) { continue }
                if protectedBundleIdentifiers.contains(bundleID) { continue }
                if app == NSRunningApplication.current { continue }
                block(application: app, bundleID: bundleID)
            }
        }
    }

    func minimizeDistractions() {
        if shouldBypassEnforcementForFullscreen() { return }

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if app == NSRunningApplication.current { continue }
            if protectedBundleIdentifiers.contains(bundleID) { continue }

            switch sessionMode {
            case .allowList:
                if !allowedBundleIDs.contains(bundleID) {
                    app.hide()
                }
            case .blockList:
                if blockedBundleIDs.contains(bundleID) {
                    app.hide()
                }
            }
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

    private func registerForCloudHistoryUpdates() {
        CloudSyncManager.shared.sessionHistoryDidChange = { [weak self] records in
            Task { @MainActor in
                guard let self else { return }
                guard UserDefaults.standard.bool(forKey: "dialedIn.syncAcrossDevices") else { return }
                self.importSessionHistoryFromCloud(records)
            }
        }
    }

    private func shouldBypassEnforcementForFullscreen() -> Bool {
        guard disableWhileFullscreen, isSessionActive else { return false }
        return FullscreenStateMonitor.isFrontmostApplicationFullscreen()
    }

}
