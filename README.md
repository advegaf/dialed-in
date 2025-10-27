# Dialed In

Dialed In is a macOS menu bar app (SwiftUI + AppKit) that helps you get into deep work. Start focused sessions, see a live timer in the menu bar, and keep distractions at bay by selecting apps to block during a session.

## Features
- Focus sessions with a clean, large timer UI
- Menu bar status with remaining time and quick controls
- App selection to block common distractions during a session
- Keyboard shortcuts for fast control (start, add time, end)
- Onboarding, session complete modal, and subtle toasts

## Stack
- Swift 5, SwiftUI, AppKit (macOS app)
- Xcode project: `Dialed In.xcodeproj`

## Getting started
1. Open `Dialed In.xcodeproj` in Xcode (latest stable recommended).
2. Select the "Dialed In" scheme and build/run.

## Project structure (high level)
- `Dialed In/` – App sources
  - `Models/` – Session/state controllers, hotkey manager, app inventory
  - `Views/` – SwiftUI views (timer, onboarding, app selection, etc.)
  - `MenuBarManager.swift` – Menu bar icon, menu, and status
  - `Dialed_InApp.swift` – App entry point

## Contributing
Issues and PRs are welcome. Before contributing, run through a full build in Xcode and test a couple of focus sessions to validate changes.

## Notes
- A separate internal roadmap document exists locally but is intentionally not pushed to the repository. Upon me making it public I will change the license type for further contributions!
