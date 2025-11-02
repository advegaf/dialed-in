//
//  Dialed_InApp.swift
//  Dialed In
//
//  Created by Angel Vega on 10/25/25.
//

import SwiftUI
import AppKit

@main
struct Dialed_InApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var sessionController: FocusSessionController
    @StateObject private var windowController: WindowStateController
    @StateObject private var templateStore: SessionTemplateStore
    private let templateScheduler: SessionTemplateScheduler

    init() {
        let windowController = WindowStateController()
        _windowController = StateObject(wrappedValue: windowController)

        let menuManager = MenuBarManager()
        menuManager.windowController = windowController
        _menuBarManager = StateObject(wrappedValue: menuManager)

        let sessionController = FocusSessionController(menuBarManager: menuManager)
        _sessionController = StateObject(wrappedValue: sessionController)

        let templateStore = SessionTemplateStore()
        _templateStore = StateObject(wrappedValue: templateStore)

        templateScheduler = SessionTemplateScheduler(templateStore: templateStore, sessionController: sessionController)

        appDelegate.sessionController = sessionController
        appDelegate.windowController = windowController
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuBarManager)
                .environmentObject(sessionController)
                .environmentObject(windowController)
                .environmentObject(templateStore)
                .frame(width: 960, height: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove unnecessary menu items for cleaner experience
            CommandGroup(replacing: .newItem) {}
        }
    }
}
