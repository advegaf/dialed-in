//
//  SessionCompleteModal.swift
//  Dialed In
//
//  Completion overlay shown when a focus session ends
//

import SwiftUI

struct SessionCompleteModal: View {
    let durationMinutes: Int
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Modal card
            VStack(spacing: Spacing.xl) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .regular))
                        .foregroundColor(.green)
                        .scaleEffect(showCheckmark ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCheckmark)
                }
                .padding(.top, Spacing.lg)

                // Title and message
                VStack(spacing: Spacing.sm) {
                    Text("Session Complete!")
                        .font(Typography.largeTitle)
                        .foregroundColor(.textPrimary)

                    Text("You stayed focused for \(durationMinutes) minute\(durationMinutes == 1 ? "" : "s")")
                        .font(Typography.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Stats card
                HStack(spacing: Spacing.xl) {
                    StatItem(icon: "clock.fill", value: "\(durationMinutes)", label: "Minutes")
                    StatItem(icon: "checkmark.shield.fill", value: "100%", label: "Focus")
                }
                .padding(Spacing.lg)
                .background(Color.contentBackground)
                .cornerRadius(CornerRadius.md)

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(Typography.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accent)
                        .cornerRadius(CornerRadius.button)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.appBackground)
            )
            .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCheckmark = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(Typography.title)
                .foregroundColor(.accent)

            Text(value)
                .font(Typography.title)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(label)
                .font(Typography.caption)
                .foregroundColor(.textSecondary)
        }
    }
}

struct SessionCompleteModal_Previews: PreviewProvider {
    static var previews: some View {
        SessionCompleteModal(durationMinutes: 30) {}
    }
}
