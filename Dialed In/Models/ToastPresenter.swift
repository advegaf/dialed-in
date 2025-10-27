import AppKit
import SwiftUI

@MainActor
final class ToastPresenter {
    static let shared = ToastPresenter()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<GlobalToastView>?
    private var hideWorkItem: DispatchWorkItem?
    private var appName: String = ""

    private init() {}

    func show(appName: String) {
        self.appName = appName

        if panel == nil {
            createPanel()
        }

        guard let panel, let hostingView else { return }

        hostingView.rootView = GlobalToastView(appName: appName) { [weak self] in
            self?.panel?.orderOut(nil)
        }
        positionPanel(panel)
        panel.orderFrontRegardless()

        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func createPanel() {
        let contentRect = CGRect(x: 0, y: 0, width: 320, height: 96)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: GlobalToastView(appName: appName) { [weak panel] in panel?.orderOut(nil) })
        hostingView.frame = contentRect
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let panelSize = panel.frame.size
        let screenFrame = screen.visibleFrame
        let origin = CGPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}


private struct GlobalToastView: View {
    let appName: String
    let onDismiss: () -> Void
    @State private var isShowing: Bool = true

    var body: some View {
        BlockAlertToast(appName: appName, isShowing: $isShowing, onDismiss: onDismiss)
            .onChange(of: isShowing) { _, value in
                if !value {
                    onDismiss()
                }
            }
    }
}
