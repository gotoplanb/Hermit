# Building Hermit: An SSH Client for Claude Code in One Session

## The Origin Story

It started as a joke. Someone posted a fake Apple keyboard online that only had three keys — 1, 2, and 3. The punchline was obvious to anyone who uses Claude Code: that's basically all you need. Accept, reject, or edit. Three buttons.

I made my own variation: five keys. 1, 2, 3, Escape, and a microphone. Showed it to a friend, laughing — "This is literally all I need now." Five keys to run an entire coding workflow from my phone.

Then the joke became a question: why build hardware when I could build software? I don't need a custom keyboard. I need an SSH client with exactly five soft keys and voice input. Connect to my dev machine, attach to a tmux session where Claude Code is running, and interact with it using just those buttons.

That's how Hermit was born.

## What Is Hermit?

Hermit is an iOS SSH client purpose-built for one workflow: connecting to remote dev machines and interacting with Claude Code through tmux sessions. It's not a general-purpose terminal emulator. It's a productivity tool for a developer who lives in tmux and Claude Code on their phone.

The core idea: you're away from your desk, but Claude Code is still running on your dev machine. You pull out your phone, open Hermit, tap your session, and you're connected. Need to approve a tool call? Tap "1". Need to cancel? Tap "esc". Need to dictate a complex instruction? Tap the mic button, speak it, proofread, and send.

## Building It in One Session

The entire app was built from spec to working SSH client in a single Claude Code session. Here's the timeline:

### Foundation
- Started with a detailed spec document covering data models, navigation structure, views, and architecture decisions
- Chose Swift/SwiftUI, Citadel (SwiftNIO SSH) for connections, and xterm.js in a WKWebView for terminal rendering
- iOS 17 minimum, portrait only, dark mode enforced

### The UI Layer
- **SessionListView** — hosts grouped with their sessions, tap to connect
- **NewHostView / NewSessionView** — create hosts with connection details, sessions that attach to tmux
- **TerminalView** — xterm.js terminal taking up most of the screen, ribbon bar of soft keys at the bottom
- **VoiceInputModal** — text editor sheet for dictation, with Send button that pipes text to the SSH session
- **SettingsView** — voice provider selection, iCloud sync status
- **AboutView** — shows on first launch with open source notice and donation link to upstream projects

### Data & Sync
- JSON persistence with automatic iCloud Drive sync via ubiquitous containers
- `NSFileCoordinator` for safe file access, `NSMetadataQuery` to watch for remote changes
- The data file lives at `iCloud Drive/Hermit/Documents/hermit-data.json` — you can edit it from your Mac via Finder
- Private keys stored in iOS Keychain, never in the data file
- This means a Claude Code session on your Mac can programmatically update your hosts and sessions by writing to the JSON file, and Hermit picks up the changes automatically

### SSH Integration
- Integrated Citadel library for real SSH connections with ed25519 private key authentication
- PTY shell sessions with xterm-256color terminal type
- tmux attach on connect (`tmux new-session -As <name>`)
- Terminal size synchronization — xterm.js fit addon reports actual dimensions to Swift, which tells the PTY the correct size
- This fixed two major issues: text overflow (80-column PTY on a narrower phone) and Claude Code's status line repeating instead of updating in-place

### The Terminal Rendering Journey
- xterm.js initially loaded from CDN — worked in simulator but blank on real devices
- Bundled xterm.js, xterm.css, and fit addon locally into the app
- Terminal was still blank — turned out the stub SSH data was being written before xterm.js finished loading
- Added a ready-signal system: xterm.js sends "terminalReady" message to Swift, WebViewStore buffers all data until then
- Finally: real terminal rendering on device

### The Soft Keys
- Default ribbon: 1, 2, 3, esc, mic
- Initially sent `"1\n"` — didn't work for Claude Code's raw-mode approval prompts
- Changed to bare keystrokes (`"1"`, `"2"`, `"3"`) — Claude Code reads single characters in raw mode
- Escape sends `\u{1B}`, mic opens the voice input modal
- The buttons are per-host configurable, stored in the host's `RibbonConfig`

### Voice Input
- Tap mic on the ribbon bar
- VoiceInputModal opens with a TextEditor — iOS keyboard dictation works great here
- Proofread the transcription, tap Send
- Text gets piped to the SSH session with a carriage return appended
- Super Whisper URL scheme integration is plumbed but not needed yet — iOS built-in dictation is surprisingly good for this use case

### Deployment Pipeline
- Fastlane configured with App Store Connect API key auth
- `bundle exec fastlane beta` — one command to increment build number, archive, sign, and upload to TestFlight
- `ITSAppUsesNonExemptEncryption` flag in Info.plist so builds auto-approve without compliance prompts
- For development: check if iPhone is connected, build and install directly for fast iteration; fall back to TestFlight when phone isn't available

### Challenges & Fixes
- **Bundle ID conflict** — `com.hermit.app` was taken, switched to `com.zeromissionllc.hermit`
- **Legacy resolution** — missing `UILaunchScreen` in Info.plist caused the app to render at iPhone 3G resolution
- **Empty PRODUCT_NAME** — caused "missing bundle ID" errors on install
- **Citadel version** — spec referenced 0.26.0 which doesn't exist, found 0.9.2 as latest
- **Ed25519 key parsing** — wrote a custom OpenSSH private key parser, had an off-by-4-bytes bug in the seed extraction
- **iCloud entitlements** — needed explicit container ID registration in the Apple Developer portal
- **Terminal width** — hardcoded 80x24 PTY didn't match phone screen, causing overflow and status line spam

## The Recursive Loop

The funniest moment: testing the app in the iOS simulator while Claude Code was connected to the same tmux session. Every action Claude took appeared in the terminal, which Claude then tried to respond to, creating an infinite loop of self-interaction. We had to use the real phone for testing approval prompts.

## What's Next

- Real-device testing of the full workflow
- UI polish based on daily use
- Per-host ribbon customization in the UI
- Potentially Super Whisper integration if iOS dictation proves insufficient
- Word substitution dictionary for common voice-to-text corrections

## Open Source

Hermit is open source at [github.com/gotoplanb/Hermit](https://github.com/gotoplanb/Hermit). The code is public so anyone can review exactly what runs on their device and how SSH credentials are handled. If you find it useful, consider donating to one of the upstream projects that make it possible: Citadel, xterm.js, or SwiftNIO.

## The Meta Moment

By the end of the session, the app was being used to build itself. Dictating instructions into Hermit's voice modal, approving Claude Code's tool calls with the 1/2/3 buttons, watching the terminal output scroll by on a phone screen. The five-key joke keyboard became a real product in about eight hours.
