import Foundation
import AppKit

enum ApplicationInventory {
    static func fetchInstalledApplications() async -> [AppItem] {
        await Task.detached(priority: .utility) {
            loadApplications()
        }.value
    }

    private static func loadApplications() -> [AppItem] {
        var collected: [String: AppItem] = [:]
        let fileManager = FileManager.default

        for directory in applicationDirectories() {
            guard fileManager.fileExists(atPath: directory.path) else { continue }

            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            )

            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension.lowercased() != "app" {
                    continue
                }

                enumerator?.skipDescendants()

                guard let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      collected[bundleIdentifier] == nil else {
                    continue
                }

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = makeIcon(for: url)

                let item = AppItem(
                    name: displayName,
                    bundleIdentifier: bundleIdentifier,
                    icon: icon,
                    bundleURL: url,
                    isSelected: false
                )
                collected[bundleIdentifier] = item
            }
        }

        return collected.values
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private static func applicationDirectories() -> [URL] {
        var directories: [URL] = []
        let fm = FileManager.default

        func appendUnique(_ url: URL) {
            guard !directories.contains(url) else { return }
            directories.append(url)
        }

        let staticPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        for path in staticPaths {
            appendUnique(URL(fileURLWithPath: path, isDirectory: true))
        }

        let domainMasks: [FileManager.SearchPathDomainMask] = [.userDomainMask, .localDomainMask]
        for mask in domainMasks {
            let urls = fm.urls(for: .applicationDirectory, in: mask)
            urls.forEach { appendUnique($0) }
        }

        return directories.filter { fm.fileExists(atPath: $0.path) }
    }

    private static func makeIcon(for url: URL) -> NSImage? {
        let workspaceIcon = NSWorkspace.shared.icon(forFile: url.path)
        guard let iconCopy = workspaceIcon.copy() as? NSImage else {
            return workspaceIcon
        }
        iconCopy.size = NSSize(width: 64, height: 64)
        iconCopy.isTemplate = false
        return iconCopy
    }
}
