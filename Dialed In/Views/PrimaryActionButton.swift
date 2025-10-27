//
//  PrimaryActionButton.swift
//  Dialed In
//
//  Large primary action button with states and animations
//

import SwiftUI

enum ActionButtonState {
    case startFocus
    case endSession
    case loading

    var title: String {
        switch self {
        case .startFocus:
            return "Start Focus Session"
        case .endSession:
            return "End Session"
        case .loading:
            return "Starting..."
        }
    }

    var icon: String {
        switch self {
        case .startFocus:
            return "play.fill"
        case .endSession:
            return "stop.fill"
        case .loading:
            return "ellipsis"
        }
    }

    var isPrimary: Bool {
        self == .startFocus || self == .loading
    }
}

struct PrimaryActionButton: View {
    let state: ActionButtonState
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            if isEnabled {
                // Haptic feedback
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
                action()
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: state.icon)
                    .font(Typography.headline)

                Text(state.title)
                    .font(Typography.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(buttonBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.button)
                            .stroke(buttonBorder, lineWidth: state.isPrimary ? 0 : 1.5)
                    )
            )
            .foregroundColor(buttonForeground)
            .shadow(
                color: buttonShadow,
                radius: isHovered ? 14 : 10,
                x: 0,
                y: isHovered ? 8 : 5
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .pressEvents(
            onPress: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = true
                }
            },
            onRelease: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        )
        .cursor(isHovered && isEnabled ? .pointingHand : .arrow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isEnabled ? "Activate to \(state == .startFocus ? "begin focus session" : "end current session")" : "Button disabled")
    }

    private var buttonBackground: AnyShapeStyle {
        if state.isPrimary {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Palette.accent, Palette.accentGlow.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    private var buttonForeground: Color {
        if state.isPrimary {
            return .white
        } else {
            return .red
        }
    }

    private var buttonBorder: Color {
        state.isPrimary ? Color.clear : Palette.danger.opacity(0.4)
    }

    private var buttonShadow: Color {
        if state.isPrimary {
            return Color.accent.opacity(0.3)
        } else {
            return Palette.danger.opacity(0.25)
        }
    }
}

// Press events modifier
struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onPress()
                    }
                    .onEnded { _ in
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActions(onPress: onPress, onRelease: onRelease))
    }
}

struct PrimaryActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            PrimaryActionButton(state: .startFocus, isEnabled: true) {}
            PrimaryActionButton(state: .endSession, isEnabled: true) {}
            PrimaryActionButton(state: .loading, isEnabled: false) {}
        }
        .padding()
        .background(Color.appBackground)
    }
}
