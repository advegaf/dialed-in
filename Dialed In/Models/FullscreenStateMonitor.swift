import AppKit
import CoreGraphics

enum FullscreenStateMonitor {
    static func isFrontmostApplicationFullscreen() -> Bool {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements, .optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let screenSizes = NSScreen.screens.map { $0.frame.size }
        let tolerance: CGFloat = 2.0

        for windowInfo in windowInfoList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == frontmostApplication.processIdentifier else {
                continue
            }

            guard let boundsDictionary = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = boundsDictionary["Width"],
                  let height = boundsDictionary["Height"] else {
                continue
            }

            let windowSize = CGSize(width: width, height: height)
            if screenSizes.contains(where: { screenSize in
                abs(screenSize.width - windowSize.width) <= tolerance &&
                abs(screenSize.height - windowSize.height) <= tolerance
            }) {
                return true
            }
        }

        return false
    }
}
