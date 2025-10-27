//
//  BlockAlertToast.swift
//  Dialed In
//
//  Toast notification shown when an app is blocked
//

import SwiftUI

struct BlockAlertToast: View {
    let appName: String
    @Binding var isShowing: Bool
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Warning icon
            Image(systemName: "exclamationmark.shield.fill")
                .font(Typography.title)
                .foregroundColor(.orange)

            // Message
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("App Blocked")
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Text(appName)
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Close button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowing = false
                    onDismiss?()
                }
            }) {
                Image(systemName: "xmark")
                    .font(Typography.micro)
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(CornerRadius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowing = false
                    onDismiss?()
                }
            }
        }
    }
}

struct BlockAlertToast_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            BlockAlertToast(appName: "Safari", isShowing: .constant(true))
                .padding()

            Spacer()
        }
        .frame(height: 400)
        .background(Color.appBackground)
    }
}
