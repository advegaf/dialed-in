//
//  OnboardingView.swift
//  Dialed In
//
//  Premium welcome screen - Flighty-inspired sophistication
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    @State private var iconScale: CGFloat = 0.9
    @State private var iconOpacity: Double = 0

    var body: some View {
        ZStack {
            // Clean background - dark mode aware
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            // Subtle noise texture overlay for depth
            Rectangle()
                .fill(Color.black.opacity(0.02))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon - clean and minimal
                ZStack {
                    // Subtle shadow circle
                    Circle()
                        .fill(Color.black.opacity(0.04))
                        .frame(width: 96, height: 96)
                        .blur(radius: 20)
                        .offset(y: 10)

                    // Icon
                    Image(systemName: "moon.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundColor(Color(hex: "0A84FF"))
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                Spacer()
                    .frame(height: 48)

                // App name - refined typography
                VStack(spacing: 12) {
                    Text("Dialed In")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.primary)
                        .tracking(-0.5)

                    Text("Focus. Uninterrupted.")
                        .font(Typography.body)
                        .foregroundColor(.secondary)
                        .tracking(0.2)
                }
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()
                    .frame(height: 64)

                // Features - clean and informative
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "app.badge.checkmark",
                        title: "Block Distractions",
                        description: "Choose which apps to restrict during focus sessions"
                    )

                    FeatureRow(
                        icon: "clock",
                        title: "Set Your Duration",
                        description: "From 15 minutes to 2 hours—you're in control"
                    )

                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Build Better Habits",
                        description: "Track your progress and maintain consistency"
                    )
                }
                .padding(.horizontal, 48)
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()

                // CTA - clean and inviting
                Button(action: {
                    completeOnboarding()
                }) {
                    Text("Get Started")
                        .font(Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "0A84FF"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 48)
                .opacity(contentOpacity)
                .offset(y: contentOffset)

                Spacer()
                    .frame(height: 48)
            }
        }
        .onAppear {
            animateEntrance()
        }
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            contentOpacity = 1.0
            contentOffset = 0
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showOnboarding = false
        }
    }
}

// Clean feature row component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(Typography.title)
                .foregroundColor(Color(hex: "0A84FF"))
                .frame(width: 28, height: 28)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.subheadline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(Typography.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
            .frame(width: 600, height: 700)
    }
}
