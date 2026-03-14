<p align="center">
  <img src="hermit-256.png" alt="Hermit" width="128">
</p>

# Hermit

A focused iOS SSH client built for developers who live in tmux and Claude Code.

Hermit is not a general-purpose terminal emulator. It connects to remote dev machines, attaches to named tmux sessions, and provides configurable soft keys and voice input for working with Claude Code from your phone.

## Features

- SSH connections with private key authentication
- tmux session attach or raw shell
- Configurable ribbon bar with soft keys (send strings, ESC, voice input)
- xterm.js terminal rendering via WKWebView
- Super Whisper voice transcription integration
- Automatic iCloud Drive sync across devices
- Dark mode enforced
- Portrait-only for v1

## Requirements

- iOS 17+
- Xcode 16+

## Getting Started

1. Clone the repo
2. Open `Hermit/Hermit.xcodeproj` in Xcode
3. Build and run on a simulator or device

### iCloud Drive Sync

Session and host configuration is stored in `hermit-data.json` in your iCloud Drive container. This syncs automatically across all devices signed into the same iCloud account. You can edit this file directly from a Mac:

```
# In Finder
iCloud Drive → Hermit → Documents → hermit-data.json

# Or via terminal
~/Library/Mobile Documents/iCloud~com~zeromissionllc~hermit/Documents/hermit-data.json
```

Private keys are stored in the iOS Keychain and do not sync — they must be added per device.

### Fastlane

TestFlight and App Store deployment is automated via Fastlane.

```bash
cd Hermit
bundle install
cp fastlane/.env.example fastlane/.env
# Fill in your credentials in .env
bundle exec fastlane beta      # Upload to TestFlight
bundle exec fastlane release   # Submit for App Store review
```

See `fastlane/.env.example` for required environment variables.

## Architecture

| Concern | Decision |
|---------|----------|
| Language | Swift, SwiftUI |
| SSH Library | Citadel (SwiftNIO SSH) — integration pending |
| Terminal | xterm.js in WKWebView |
| Data persistence | JSON in iCloud Drive (local fallback) |
| Key storage | iOS Keychain |
| Code signing | Xcode automatic signing |

## Project Structure

```
Hermit/
├── App/            # App entry point, URL scheme handling
├── Models/         # Host, Session, RibbonConfig, AppSettings
├── Storage/        # DataStore (JSON + iCloud), KeychainManager
├── SSH/            # SSHConnectionManager, TerminalBridge (WKWebView)
├── Voice/          # VoiceInputCoordinator, SuperWhisperProvider
├── Views/          # All SwiftUI views
├── Resources/      # terminal.html (xterm.js bundle)
└── fastlane/       # Fastfile, Matchfile, Appfile
```

## Open Source

Hermit is open source so you can review exactly what runs on your device and how your SSH credentials are handled. Licensed for personal use — this software may not be sold or redistributed commercially.

## Support Open Source

If you find Hermit useful, consider donating to one of the projects that make it possible:

- [Citadel](https://github.com/orlandos-nl/Citadel) — Swift SSH library built on SwiftNIO
- [xterm.js](https://github.com/xtermjs/xterm.js) — Terminal frontend component
- [SwiftNIO](https://github.com/apple/swift-nio) — Event-driven networking framework for Swift

## License

Personal use only. See [LICENSE](LICENSE) for details.
