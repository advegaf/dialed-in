import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowStateController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var window: NSWindow?

    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        configure(window)
    }

    func showWindow() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func configure(_ window: NSWindow) {
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MainWindow")
        window.collectionBehavior.insert(.fullScreenNone)
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct WindowAccessor: NSViewRepresentable {
    @ObservedObject var controller: WindowStateController

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if controller.window == nil, let window = view.window {
                controller.attach(to: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if controller.window == nil, let window = nsView.window {
                controller.attach(to: window)
            }
        }
    }
}
