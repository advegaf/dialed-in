//
//  ContentView.swift
//  Dialed In
//
//  Created by Angel Vega on 10/25/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var windowController: WindowStateController

    var body: some View {
        MainCoordinatorView()
            .background(WindowAccessor(controller: windowController))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let windowController = WindowStateController()
        let menuBarManager = MenuBarManager()
        menuBarManager.windowController = windowController
        let sessionController = FocusSessionController(menuBarManager: menuBarManager)
        let templateStore = SessionTemplateStore()

        return ContentView()
            .environmentObject(menuBarManager)
            .environmentObject(sessionController)
            .environmentObject(windowController)
            .environmentObject(templateStore)
    }
}
