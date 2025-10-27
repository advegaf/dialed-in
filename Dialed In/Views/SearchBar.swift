//
//  SearchBar.swift
//  Dialed In
//
//  Alcove-style floating search input
//

import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(Typography.body)
                .foregroundColor(Palette.textSecondary)

            TextField("Search apps", text: $searchText)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundColor(Palette.textPrimary)
                .focused($isFocused)
                .accessibilityLabel("Search for apps")
                .accessibilityValue(searchText.isEmpty ? "Empty" : searchText)

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typography.body)
                        .foregroundColor(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                .fill(Palette.sidebarHighlight.opacity(isFocused ? 0.85 : 0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                        .stroke(isFocused ? Palette.accent.opacity(0.45) : Palette.divider, lineWidth: 1)
                )
        )
        .shadow(color: Shadow.soft.opacity(isFocused ? 0.28 : 0.12), radius: isFocused ? 18 : 12, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            SearchBar(searchText: .constant(""))
            SearchBar(searchText: .constant("Safari"))
        }
        .padding()
        .background(Palette.card)
        .preferredColorScheme(.dark)
    }
}
