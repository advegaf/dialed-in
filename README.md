# Dialed In

A ruthless macOS menu bar enforcer for deep work.
Set a timer. Pick the temptations. They’re locked until time’s up.

## What it is
Dialed In is a focus tool that doesn’t negotiate. During a session, your distracting apps simply won’t open or switch to the foreground—no warnings, no popups to ignore. You stay where your work is.

## How it works
1) Start a Focus Session — presets for 15m, 30m, 1h, or custom.
2) Select Apps to Block — Slack, Twitter/X, Discord, Netflix/YouTube, etc.
3) Hard Block Enforcement — attempts to launch or switch to blocked apps are intercepted; you’ll get a gentle toast, but the switch won’t happen.
4) Menu Bar Timer — live countdown with quick actions.
5) End When Done — stop the session and everything is immediately unblocked.

## Why it’s different
This isn’t a reminder; it’s enforcement. Many “focus” apps nudge you. Dialed In denies the distraction outright until your timer ends.

## Screenshots
<p align="center">
  <img src="docs/screenshots/focus-scope.png" alt="Focus Scope (Allow/Block lists and app selection)" width="720"/>
</p>
<p align="center">
  <img src="docs/screenshots/session-timer.png" alt="Session Timer with radial countdown" width="720"/>
</p>
<p align="center">
  <img src="docs/screenshots/onboarding.png" alt="Onboarding — Dialed In overview" width="720"/>
</p>

## Features
- Hard block: fully prevents opening/switching to selected apps during a session
- Menu bar countdown with quick controls (add 5 min, end session)
- Keyboard shortcuts for fast session control (start, add time, end)
- Session completion notification
- Toast alerts if you try to access a blocked app

## Quick start
1) Open `Dialed In.xcodeproj` in Xcode (latest stable recommended).
2) Build and run the “Dialed In” scheme.
3) On first run, grant Accessibility permission when prompted (required for global hotkeys and enforcing app blocks).

## Project structure
- `Dialed In/` — app sources
  - `Models/` — session controller, app inventory, hotkey manager, window state
  - `Views/` — timer, onboarding, app selection, toasts, etc.
  - `MenuBarManager.swift` — menu bar icon, menu, and status
  - `Dialed_InApp.swift` — app entry point

## Privacy
All focus and blocking logic runs locally on your Mac. No usage data is sent anywhere.

## Contributing
Issues and PRs are welcome. Please build in Xcode and validate a few sessions (start/add time/end) before submitting changes.

## Notes
- An internal roadmap file exists locally and is intentionally not pushed to the repo.
