//
//  DurationPicker.swift
//  Dialed In
//
//  Duration picker with preset time pills
//

import SwiftUI

struct DurationOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let minutes: Int
    let icon: String

    var seconds: Int {
        minutes * 60
    }

    static let presets: [DurationOption] = [
        DurationOption(title: "15m", minutes: 15, icon: "clock"),
        DurationOption(title: "30m", minutes: 30, icon: "clock"),
        DurationOption(title: "1h", minutes: 60, icon: "clock.fill"),
        DurationOption(title: "2h", minutes: 120, icon: "clock.fill"),
    ]
}

struct DurationPicker: View {
    @Binding var selectedDuration: DurationOption
    let options: [DurationOption]

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(options) { option in
                DurationPill(
                    option: option,
                    isSelected: selectedDuration.id == option.id
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDuration = option
                    }
                }
            }
        }
    }
}

struct DurationPill: View {
    let option: DurationOption
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: option.icon)
                    .font(Typography.body)

                Text(option.title)
                    .font(Typography.body)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(isSelected ? Color.accent : Color.contentBackground)
            )
            .foregroundColor(isSelected ? .white : .textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .stroke(isSelected ? Color.clear : Color.textSecondary.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .cursor(isHovered ? .pointingHand : .arrow)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct DurationPicker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            DurationPicker(
                selectedDuration: .constant(DurationOption.presets[0]),
                options: DurationOption.presets
            )

            DurationPicker(
                selectedDuration: .constant(DurationOption.presets[2]),
                options: DurationOption.presets
            )
        }
        .padding()
        .background(Color.appBackground)
    }
}
