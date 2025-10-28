//
//  SelectedAppsPanel.swift
//  Dialed In
//
//  Bottom panel showing selected apps with blur background
//

import SwiftUI

struct SelectedAppsPanel: View {
    let selectedApps: [AppItem]
    let onRemove: (AppItem) -> Void
    var mode: FocusSessionMode = .allowList

    private var titleText: String {
        switch mode {
        case .allowList:
            return "\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") allowed"
        case .blockList:
            return "\(selectedApps.count) app\(selectedApps.count == 1 ? "" : "s") blocked"
        }
    }

    var body: some View {
        if !selectedApps.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(titleText)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(selectedApps) { app in
                            SelectedAppBadge(app: app) {
                                onRemove(app)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Palette.sidebarHighlight.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Palette.divider.opacity(0.3), lineWidth: 0.8)
                    )
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct SelectedAppBadge: View {
    let app: AppItem
    let onRemove: () -> Void

    @State private var isHovered = false

    @ViewBuilder
    private var badgeIcon: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: app.fallbackSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Palette.accent)
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Palette.sidebarHighlight.opacity(isHovered ? 0.7 : 0.55))
                    .frame(width: 56, height: 56)
                    .overlay(badgeIcon)

                if isHovered {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onRemove()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Typography.subheadline)
                            .foregroundColor(Palette.danger)
                            .padding(4)
                            .background(Circle().fill(Palette.sidebar))
                    }
                    .buttonStyle(.plain)
                    .padding(2)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(2)

            Text(app.name)
                .font(Typography.caption)
                .foregroundColor(Palette.textPrimary)
                .lineLimit(1)
                .frame(width: 60)
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
}

struct SelectedAppsPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            SelectedAppsPanel(
                selectedApps: Array(AppItem.sampleApps.prefix(4)),
                onRemove: { _ in }
            )
            .padding()
        }
        .frame(height: 400)
        .background(Palette.windowTop)
    }
}
