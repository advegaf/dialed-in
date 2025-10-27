//
//  AppCardView.swift
//  Dialed In
//
//  Card component for displaying an app in the selection grid
//

import SwiftUI

struct AppCardView: View {
    let app: AppItem
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var iconCircleFill: Color {
        isSelected ? Color.accent.opacity(0.1) : Color.contentBackground
    }

    private var iconForegroundColor: Color {
        isSelected ? .accent : .textPrimary
    }

    private var cardBackgroundFill: Color {
        isSelected ? Color.accent.opacity(0.05) : Color.clear
    }

    private var cardStrokeColor: Color {
        isSelected ? Color.accent : Color.clear
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: app.fallbackSymbolName)
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(iconForegroundColor)
        }
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // App icon
            ZStack {
                Circle()
                    .fill(iconCircleFill)
                    .frame(width: 64, height: 64)

                appIcon
            }

            // App name
            Text(app.name)
                .font(Typography.caption)
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(Typography.headline)
                    .foregroundColor(.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(cardBackgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(cardStrokeColor, lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onChange(of: isSelected) { _, _ in
            // Trigger spring animation when selection toggles
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {}
        }
        .onTapGesture {
            onTap()
        }
        .cursor(isHovered ? .pointingHand : .arrow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") this app")
    }
}

// Cursor modifier for hover state
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }
}

struct AppCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: Spacing.lg) {
            AppCardView(app: AppItem.sampleApps[0], isSelected: false) {}
            AppCardView(app: AppItem.sampleApps[1], isSelected: true) {}
        }
        .padding()
        .background(Color.appBackground)
    }
}
