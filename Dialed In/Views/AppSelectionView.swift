//
//  AppSelectionView.swift
//  Dialed In
//
//  Alcove-matched app selection surface
//

import SwiftUI

struct AppSelectionView: View {
    @EnvironmentObject private var sessionController: FocusSessionController
    @Binding var apps: [AppItem]
    let isLoading: Bool
    let loadError: String?

    @State private var searchText = ""
    @State private var hotKeyConfiguration = HotKeyManager.shared.currentConfiguration
    @State private var selectedAppIDs: Set<String> = []
    @AppStorage("dialedIn.sessionMode") private var sessionModeRawValue: String = FocusSessionMode.allowList.rawValue
    @AppStorage("dialedIn.launchAtLogin") private var launchAtLogin = true
    @AppStorage("dialedIn.syncAcrossDevices") private var syncAcrossDevices = true
    @AppStorage("dialedIn.hideMenuBarIcon") private var hideMenuBarIcon = false
    @AppStorage("dialedIn.disableWhileFullscreen") private var disableWhileFullscreen = false
    @AppStorage("dialedIn.hapticFeedbackEnabled") private var hapticFeedbackEnabled = true
    @AppStorage("dialedIn.expandOnHover") private var expandOnHover = true
    @AppStorage("dialedIn.hoverPreviewDelay") private var hoverPreviewDelay: Double = 0.2

    private var filteredApps: [AppItem] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedApps: [AppItem] { apps.filter { selectedAppIDs.contains($0.id) } }
    private var isFiltering: Bool { !searchText.isEmpty }
    private var sessionMode: FocusSessionMode { FocusSessionMode(rawValue: sessionModeRawValue) ?? .allowList }
    private var sessionModeBinding: Binding<FocusSessionMode> {
        Binding(
            get: { sessionMode },
            set: { sessionModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Palette.divider.opacity(0.25), lineWidth: 0.8)
                )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    header
                        .padding(.bottom, Spacing.lg)

                    settingsCard(title: "System") {
                        SettingToggleRow(
                            title: "Launch at login",
                            description: "Dialed In opens automatically when you sign in.",
                            isOn: $launchAtLogin
                        )
                        divider
                        SettingToggleRow(
                            title: "Sync settings across devices",
                            description: "Use the same focus rules on every Mac.",
                            isOn: $syncAcrossDevices
                        )
                        divider
                        SettingToggleRow(
                            title: "Hide menu bar icon",
                            description: "Keeps Dialed In invisible while you’re locked in.",
                            isOn: $hideMenuBarIcon
                        )
                        divider
                        SettingToggleRow(
                            title: "Disable while in fullscreen",
                            description: "Skip blocking when an app is already fullscreen.",
                            isOn: $disableWhileFullscreen
                        )
                    }

                    settingsCard(title: "Behaviour") {
                        SettingToggleRow(
                            title: "Haptic feedback",
                            description: "Feel a tactile click when you adjust session time.",
                            isOn: $hapticFeedbackEnabled
                        )
                        divider
                        SettingToggleRow(
                            title: "Expand allow list on hover",
                            description: "Peek at approved apps without leaving focus.",
                            isOn: $expandOnHover
                        )
                        divider
                        SettingSliderRow(
                            title: "Hover duration",
                            description: "Delay before the allow list peeks open.",
                            value: $hoverPreviewDelay,
                            range: 0.1...1.0,
                            displayValue: String(format: "%.1f s", hoverPreviewDelay)
                        )
                        divider
                        HotKeyRecorderRow(configuration: $hotKeyConfiguration)
                    }

                    focusScopeCard

                    if !selectedApps.isEmpty {
                        SelectedAppsPanel(
                            selectedApps: selectedApps,
                            onRemove: deselect,
                            mode: sessionMode
                        )
                        .allowsHitTesting(!sessionController.isSessionActive && !isLoading)
                        .opacity((sessionController.isSessionActive || isLoading) ? 0.6 : 1.0)
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
            }
        }
        .background(Color.clear)
        .onAppear {
            hotKeyConfiguration = HotKeyManager.shared.currentConfiguration
            if selectedAppIDs.isEmpty {
                let storedIDs = Set(UserDefaults.standard.stringArray(forKey: "dialedIn.selectedAppIDs") ?? [])
                let currentSelections = Set(apps.filter { $0.isSelected }.map { $0.id })
                selectedAppIDs = currentSelections.union(storedIDs)
                syncAppsWithSelectedIDs()
                persistSelection()
            } else {
                syncAppsWithSelectedIDs()
            }
        }
        .onChange(of: apps) { _, newValue in
            let currentSelections = Set(newValue.filter { $0.isSelected }.map { $0.id })
            if !currentSelections.isEmpty {
                selectedAppIDs.formUnion(currentSelections)
            }
            syncAppsWithSelectedIDs()
            persistSelection()
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.55))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Palette.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(Typography.largeTitle)
                    .foregroundColor(Palette.textPrimary)

                Text("Dialed In blocks everything except the apps you approve for this session.")
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func settingsCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.headline)
                .foregroundColor(Palette.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Palette.sidebarHighlight.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Palette.divider.opacity(0.35), lineWidth: 0.8)
                    )
            )
        }
    }

    private var divider: some View {
        Divider().overlay(Palette.divider)
    }

    private var focusScopeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Focus Scope")
                .font(Typography.headline)
                .foregroundColor(Palette.textPrimary)

            Text("Choose how tightly Dialed In restricts your Mac during this session.")
                .font(Typography.body)
                .foregroundColor(Palette.textSecondary)

            SessionModeSelector(selection: sessionModeBinding)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                SearchBar(searchText: $searchText)

                if isLoading {
                    loadingState
                } else if filteredApps.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppToggleRow(
                                app: app,
                                isSelected: binding(for: app)
                            )

                            if app.id != filteredApps.last?.id {
                                Divider().overlay(Palette.divider)
                            }
                        }
                    }
                    .disabled(sessionController.isSessionActive || isLoading)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Palette.sidebarHighlight.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                    .stroke(Palette.divider.opacity(0.3), lineWidth: 0.8)
                            )
                    )
                }
            }
        }
        .padding(Spacing.gutter)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Palette.divider.opacity(0.35), lineWidth: 0.8)
                )
        )
    }

    private var loadingState: some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
            Text("Loading applications…")
                .font(Typography.body)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.55))
        )
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: isFiltering ? "magnifyingglass" : "app")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Palette.textSecondary)

            if isFiltering {
                Text("No apps match \"\(searchText)\"")
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
                Text("Try searching for a different app or clear the filter.")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textTertiary)
            } else if let loadError = loadError {
                Text(loadError)
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Text("Showing sample apps until we can index your Applications folder.")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No applications found")
                    .font(Typography.body)
                    .foregroundColor(Palette.textSecondary)
                Text("Install apps in /Applications to see them here.")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.55))
        )
    }


    private func binding(for app: AppItem) -> Binding<Bool> {
        Binding(
            get: { selectedAppIDs.contains(app.id) },
            set: { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    updateSelection(for: app, isSelected: newValue)
                }
            }
        )
    }

    private func deselect(_ app: AppItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            updateSelection(for: app, isSelected: false)
        }
    }

    private func updateSelection(for app: AppItem, isSelected: Bool) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected = isSelected
        }

        if isSelected {
            selectedAppIDs.insert(app.id)
        } else {
            selectedAppIDs.remove(app.id)
        }

        syncAppsWithSelectedIDs()
        persistSelection()
    }

    private func syncAppsWithSelectedIDs() {
        for index in apps.indices {
            let shouldSelect = selectedAppIDs.contains(apps[index].id)
            if apps[index].isSelected != shouldSelect {
                apps[index].isSelected = shouldSelect
            }
        }
    }

    private func persistSelection() {
        UserDefaults.standard.set(Array(selectedAppIDs), forKey: "dialedIn.selectedAppIDs")
    }
}

struct SettingToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                Text(description)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Palette.accent))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
    }
}

struct SettingSliderRow: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typography.body)
                        .foregroundColor(Palette.textPrimary)
                    Text(description)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                }

                Spacer()

                Text(displayValue)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Palette.sidebarHighlight.opacity(0.6))
                    )
            }

            Slider(value: $value, in: range, step: 0.1)
                .tint(Palette.accent)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
    }
}

private struct SessionModeSelector: View {
    @Binding var selection: FocusSessionMode
    @Namespace private var animation

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(FocusSessionMode.allCases) { mode in
                let isSelected = mode == selection

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: mode.icon)
                            .font(Typography.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.rawValue)
                                .font(Typography.body)
                            Text(mode.subtitle)
                                .font(Typography.caption)
                                .foregroundColor(Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(isSelected ? Palette.textPrimary : Palette.textSecondary)
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                    .fill(Palette.sidebarHighlight.opacity(0.65))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                            .stroke(Palette.accent.opacity(0.45), lineWidth: 1)
                                    )
                                    .matchedGeometryEffect(id: "mode", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Palette.divider.opacity(0.3), lineWidth: 0.8)
                )
        )
    }
}

private struct AppToggleRow: View {
    let app: AppItem
    @Binding var isSelected: Bool
    @State private var isHovered = false

    @ViewBuilder
    private var appIcon: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            Image(systemName: app.fallbackSymbolName)
                .font(Typography.subheadline)
                .foregroundColor(isSelected ? Palette.accent : Palette.textSecondary)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(isSelected ? 0.65 : 0.45))
                .frame(width: 36, height: 36)
                .overlay(appIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                Text(app.bundleIdentifier)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelected = newValue
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: Palette.accent))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(isHovered ? Palette.sidebarHighlight.opacity(0.65) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


struct AppSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let windowController = WindowStateController()
        let menuBarManager = MenuBarManager()
        menuBarManager.windowController = windowController
        let sessionController = FocusSessionController(menuBarManager: menuBarManager)

        return AppSelectionView(apps: .constant(AppItem.sampleApps), isLoading: false, loadError: nil)
            .environmentObject(sessionController)
            .environmentObject(windowController)
            .preferredColorScheme(.dark)
            .frame(width: 960, height: 680)
    }
}
