import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var sessionController: FocusSessionController?
    weak var windowController: WindowStateController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureHotKey()
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if sessionController?.isSessionActive == true {
            windowController?.showWindow()
            return .terminateCancel
        }
        return .terminateNow
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowController?.showWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    private func configureHotKey() {
        HotKeyManager.shared.onActivate = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.sessionController?.isSessionActive == true {
                    self.sessionController?.endSession()
                }
                self.windowController?.showWindow()
            }
        }
        HotKeyManager.shared.registerDefaultHotKey()
    }
}
