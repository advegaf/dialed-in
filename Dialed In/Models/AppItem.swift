//
//  AppItem.swift
//  Dialed In
//
//  Model representing an application that can be blocked/allowed
//

import SwiftUI
import AppKit

struct AppItem: Identifiable, Hashable {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    let bundleURL: URL?
    var isSelected: Bool
    let fallbackSymbolName: String

    var id: String { bundleIdentifier }

    init(
        name: String,
        bundleIdentifier: String,
        icon: NSImage? = nil,
        bundleURL: URL? = nil,
        isSelected: Bool = false,
        fallbackSymbolName: String = "app.fill"
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.bundleURL = bundleURL
        self.isSelected = isSelected
        self.fallbackSymbolName = fallbackSymbolName
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    // Sample data for development & previews
    static let sampleApps: [AppItem] = [
        AppItem(name: "Safari", bundleIdentifier: "com.apple.Safari", fallbackSymbolName: "safari"),
        AppItem(name: "Messages", bundleIdentifier: "com.apple.MobileSMS", fallbackSymbolName: "message.fill"),
        AppItem(name: "Mail", bundleIdentifier: "com.apple.mail", fallbackSymbolName: "envelope.fill"),
        AppItem(name: "Twitter", bundleIdentifier: "com.twitter.twitter-mac", fallbackSymbolName: "bird"),
        AppItem(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", fallbackSymbolName: "bubble.left.and.bubble.right.fill"),
        AppItem(name: "Discord", bundleIdentifier: "com.hnc.Discord", fallbackSymbolName: "quote.bubble.fill"),
        AppItem(name: "YouTube", bundleIdentifier: "com.google.YouTube", fallbackSymbolName: "play.rectangle.fill"),
        AppItem(name: "Instagram", bundleIdentifier: "com.instagram.instagram", fallbackSymbolName: "camera.fill"),
        AppItem(name: "Facebook", bundleIdentifier: "com.facebook.Facebook", fallbackSymbolName: "person.3.fill"),
        AppItem(name: "Reddit", bundleIdentifier: "com.reddit.Reddit", fallbackSymbolName: "text.bubble.fill"),
        AppItem(name: "Netflix", bundleIdentifier: "com.netflix.Netflix", fallbackSymbolName: "tv.fill"),
        AppItem(name: "Spotify", bundleIdentifier: "com.spotify.client", fallbackSymbolName: "music.note")
    ]
}
