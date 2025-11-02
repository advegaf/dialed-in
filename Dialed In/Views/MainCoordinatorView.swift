//
//  MainCoordinatorView.swift
//  Dialed In
//
//  Alcove-style shell with sidebar navigation
//

import SwiftUI

private enum SidebarDestination: Hashable {
    case general
    case battery
    case connectivity
    case focus
    case display
    case sound
    case nowPlaying
    case calendar
    case lockScreen
    case sessionTimer
    case license
    case about
}

private struct SidebarItem: Identifiable, Hashable {
    let id: SidebarDestination
    let title: String
    let icon: String
    let tint: Color
    let isEnabled: Bool

    init(id: SidebarDestination, title: String, icon: String, tint: Color, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.tint = tint
        self.isEnabled = isEnabled
    }
}

private struct SidebarSection: Identifiable {
    let id = UUID()
    let title: String?
    let items: [SidebarItem]
}

private let sidebarSections: [SidebarSection] = [
    SidebarSection(
        title: nil,
        items: [
            SidebarItem(id: .general, title: "General", icon: "gearshape.fill", tint: Palette.textSecondary)
        ]
    ),
    SidebarSection(
        title: "Notifications",
        items: [
            SidebarItem(id: .battery, title: "Battery", icon: "bolt.fill", tint: Color(hex: "FF9F0A"), isEnabled: false),
            SidebarItem(id: .connectivity, title: "Connectivity", icon: "antenna.radiowaves.left.and.right", tint: Color(hex: "32D74B"), isEnabled: false),
            SidebarItem(id: .focus, title: "Focus", icon: "moon.fill", tint: Color(hex: "8E8CFB"), isEnabled: false),
            SidebarItem(id: .display, title: "Display", icon: "display", tint: Color(hex: "40C8FF"), isEnabled: false),
            SidebarItem(id: .sound, title: "Sound", icon: "speaker.wave.2.fill", tint: Color(hex: "FF2D55"), isEnabled: false)
        ]
    ),
    SidebarSection(
        title: "Live Activities",
        items: [
            SidebarItem(id: .nowPlaying, title: "Now Playing", icon: "play.circle.fill", tint: Color(hex: "FF375F"), isEnabled: false),
            SidebarItem(id: .calendar, title: "Calendar", icon: "calendar", tint: Color(hex: "FF453A"), isEnabled: false),
            SidebarItem(id: .lockScreen, title: "Lock Screen", icon: "lock.fill", tint: Color.white.opacity(0.85), isEnabled: false)
        ]
    ),
    SidebarSection(
        title: "Dialed In",
        items: [
            SidebarItem(id: .sessionTimer, title: "Session Timer", icon: "timer", tint: Palette.accent),
            SidebarItem(id: .license, title: "License", icon: "checkmark.seal.fill", tint: Palette.accent, isEnabled: false),
            SidebarItem(id: .about, title: "About", icon: "info.circle.fill", tint: Palette.textSecondary, isEnabled: false)
        ]
    )
]

struct MainCoordinatorView: View {
    @EnvironmentObject private var sessionController: FocusSessionController

    @State private var selectedDestination: SidebarDestination = .general
    @State private var apps: [AppItem] = []
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var isLoadingApplications = false
    @State private var applicationLoadError: String?
    @State private var hasLoadedApplications = false

    private var selectedApps: [AppItem] { apps.filter { $0.isSelected } }

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                window
            }
        }
    }

    private var window: some View {
        ZStack(alignment: .topLeading) {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Palette.windowTop, Palette.windowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarNavigationView(sections: sidebarSections, selection: $selectedDestination)
                    .frame(width: 232)

                Divider()
                    .frame(width: 0.5)
                    .overlay(Palette.divider.opacity(0.5))
                    .blendMode(.plusLighter)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 28)
                    .padding(.horizontal, 32)
            }
        }
        .task {
            await loadApplicationsIfNeeded()
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selectedDestination)
    }

    @MainActor
    private func loadApplicationsIfNeeded() async {
        guard !hasLoadedApplications else { return }
        hasLoadedApplications = true
        isLoadingApplications = true

        let loadedApps = await ApplicationInventory.fetchInstalledApplications()
        var merged = loadedApps

        if merged.isEmpty {
            applicationLoadError = "Couldn't enumerate installed applications."
            merged = AppItem.sampleApps
        } else {
            applicationLoadError = nil
        }

        let storedSelection = Set(UserDefaults.standard.stringArray(forKey: "dialedIn.selectedAppIDs") ?? [])
        let previouslySelected = Set(apps.filter { $0.isSelected }.map { $0.id })
        var selectedIDs = storedSelection.union(previouslySelected)
        if sessionController.isSessionActive {
            selectedIDs.formUnion(sessionController.activeSessionApps.map { $0.id })
        }

        if !selectedIDs.isEmpty {
            merged = merged.map { item in
                var updated = item
                if selectedIDs.contains(item.id) {
                    updated.isSelected = true
                }
                return updated
            }
        }

        apps = merged
        isLoadingApplications = false
    }

    @ViewBuilder
    private var content: some View {
        switch selectedDestination {
        case .general:
            AppSelectionView(apps: $apps, isLoading: isLoadingApplications, loadError: applicationLoadError)
        case .sessionTimer:
            TimerSessionView(apps: $apps)
        default:
            PlaceholderPane(title: "Coming Soon")
        }
    }
}

private struct SidebarNavigationView: View {
    let sections: [SidebarSection]
    @Binding var selection: SidebarDestination

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let title = section.title {
                            Text(title.uppercased())
                                .font(Typography.caption)
                                .foregroundColor(Palette.textTertiary)
                                .padding(.horizontal, 16)
                        }

                        ForEach(section.items) { item in
                            sidebarButton(for: item)
                        }
                    }
                }

                Spacer(minLength: Spacing.xl)
            }
            .padding(.vertical, Spacing.xl)
            .padding(.horizontal, 16)
        }
        .background(
            LinearGradient(
                colors: [Palette.windowTint.opacity(0.85), Palette.windowTint.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func sidebarButton(for item: SidebarItem) -> some View {
        let isSelected = item.id == selection

       return Button {
            guard item.isEnabled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                selection = item.id
            }
        } label: {
            HStack(spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                    .fill(item.tint.opacity(isSelected ? 0.22 : 0.18))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(Typography.subheadline)
                            .foregroundColor(item.tint)
                    )

                Text(item.title)
                    .font(Typography.body)
                    .foregroundColor(isSelected ? Palette.textPrimary : Palette.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                    .fill(isSelected ? Palette.sidebarHighlight.opacity(0.55) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .stroke(isSelected ? Palette.accent.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(item.isEnabled ? 1 : 0.35)
        .focusable(false)
    }
}

private struct PlaceholderPane: View {
    let title: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "hourglass")
                .font(Typography.largeTitle)
                .foregroundColor(Palette.textSecondary)
            Text(title)
                .font(Typography.headline)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct MainCoordinatorView_Previews: PreviewProvider {
    static var previews: some View {
        let menuBarManager = MenuBarManager()
        let sessionController = FocusSessionController(menuBarManager: menuBarManager)
        let templateStore = SessionTemplateStore()

        return MainCoordinatorView()
            .environmentObject(sessionController)
            .environmentObject(templateStore)
            .preferredColorScheme(.dark)
            .frame(width: 960, height: 680)
    }
}
