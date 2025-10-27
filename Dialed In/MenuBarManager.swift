//
//  MenuBarManager.swift
//  Dialed In
//
//  Manages the menu bar icon and status display
//

import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    @Published var isSessionActive: Bool = false
    @Published var remainingTime: String = ""

    weak var windowController: WindowStateController?

    init() {
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon()
            button.action = #selector(menuBarButtonClicked)
            button.target = self
        }

        menu = NSMenu()
        statusItem?.menu = menu

        updateMenu()
    }

    @objc private func menuBarButtonClicked() {
        // This will show the menu
    }

    func updateStatus(isActive: Bool, remainingSeconds: Int? = nil) {
        DispatchQueue.main.async {
            self.isSessionActive = isActive

            if isActive, let seconds = remainingSeconds {
                self.remainingTime = self.formatTime(seconds: seconds)
            } else {
                self.remainingTime = ""
            }

            self.updateIcon()
            self.updateMenu()
        }
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }

        if isSessionActive {
            // Show timer icon when active
            let icon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer Active")
            icon?.isTemplate = true
            button.image = icon

            if !remainingTime.isEmpty {
                button.title = " \(remainingTime)"
            }
        } else {
            // Show default icon when inactive
            let icon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Dialed In")
            icon?.isTemplate = true
            button.image = icon
            button.title = ""
        }
    }

    private func updateMenu() {
        guard let menu = menu else { return }
        menu.removeAllItems()

        if isSessionActive {
            // Active session menu
            let timeItem = NSMenuItem(title: "Time Remaining: \(remainingTime)", action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)

            menu.addItem(NSMenuItem.separator())

            let addTimeItem = NSMenuItem(title: "Add 5 Minutes", action: #selector(addTimeClicked), keyEquivalent: "")
            addTimeItem.target = self
            menu.addItem(addTimeItem)

            let endItem = NSMenuItem(title: "End Session", action: #selector(endSessionClicked), keyEquivalent: "")
            endItem.target = self
            menu.addItem(endItem)
        } else {
            // Inactive menu
            let statusItem = NSMenuItem(title: "No Active Session", action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        }

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "Show Dialed In", action: #selector(showAppClicked), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func addTimeClicked() {
        NotificationCenter.default.post(name: .menuBarAddTime, object: nil)
    }

    @objc private func endSessionClicked() {
        NotificationCenter.default.post(name: .menuBarEndSession, object: nil)
    }

    @objc private func showAppClicked() {
        if let controller = windowController {
            controller.showWindow()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// Notification names for menu bar actions
extension Notification.Name {
    static let menuBarAddTime = Notification.Name("menuBarAddTime")
    static let menuBarEndSession = Notification.Name("menuBarEndSession")
}
