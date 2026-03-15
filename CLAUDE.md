# CLAUDE.md

## Project Overview

Hermit is an iOS SSH client for connecting to remote dev machines, attaching to tmux sessions, and interacting with Claude Code via configurable soft keys and voice input. It is not a general-purpose terminal emulator.

## Public Repo — No Secrets

**This is a public repository.** Never commit secrets to version control:
- No `DEVELOPMENT_TEAM` in project.pbxproj
- No API keys, team IDs, or signing credentials in any committed file
- Use `fastlane/.env` (gitignored) for local secrets
- Pass `DEVELOPMENT_TEAM` via xcodebuild flags, never in the project file
- Document required vars in `fastlane/.env.example` only

## Build & Deploy

**Preferred workflow: check for connected iPhone first, fall back to TestFlight.**

```bash
# 1. Check if Dave's iPhone is connected
xcrun xctrace list devices 2>&1 | grep "iPhone"

# 2a. If connected — build, install, and launch directly (fastest iteration)
cd Hermit
xcodebuild -project Hermit.xcodeproj -scheme Hermit \
  -destination 'id=00008140-00046DA00133001C' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM_ID \
  build
xcrun devicectl device install app --device 00008140-00046DA00133001C \
  ~/Library/Developer/Xcode/DerivedData/Hermit-*/Build/Products/Debug-iphoneos/Hermit.app
xcrun devicectl device process launch --device 00008140-00046DA00133001C com.zeromissionllc.hermit

# 2b. If not connected — send to TestFlight
cd Hermit
bundle exec fastlane beta

# 3. Simulator (for UI development when device isn't needed)
xcodebuild -project Hermit.xcodeproj -scheme Hermit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Simulator Test Data

`.hermit-dev.json` in the project root (gitignored) contains host/session config and a `devPrivateKeyPath` for simulator testing. To inject test data and the SSH key:

```bash
# 1. Get the simulator app data container
DOCS=$(xcrun simctl get_app_container booted com.zeromissionllc.hermit data)/Documents
mkdir -p "$DOCS"

# 2. Copy the data file (strip the devPrivateKeyPath field)
python3 -c "
import json
with open('.hermit-dev.json') as f: d = json.load(f)
d.pop('devPrivateKeyPath', None)
with open('$DOCS/hermit-data.json', 'w') as f: json.dump(d, f, indent=2)
"

# 3. Inject the private key into the simulator's Keychain
KEY_REF=\$(python3 -c "
import json
with open('.hermit-dev.json') as f: d = json.load(f)
print(d['hosts'][0]['privateKeyRef'])
")
KEY_PATH=\$(python3 -c "
import json, os
with open('.hermit-dev.json') as f: d = json.load(f)
print(os.path.expanduser(d['devPrivateKeyPath']))
")
# Note: Simulator Keychain injection requires the app to save the key on launch.
# For now, the key is read from the file path at SSH connect time during dev.

# 4. Relaunch the app
xcrun simctl terminate booted com.zeromissionllc.hermit
xcrun simctl launch booted com.zeromissionllc.hermit
```

The simulator uses the Mac's network, so it can reach any host the Mac can (including ngrok tunnels). This enables end-to-end SSH testing once Citadel is integrated.

## Test

```bash
cd Hermit
xcodebuild test -project Hermit.xcodeproj -scheme Hermit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Tests use Swift Testing (`@Test`, `@Suite`, `#expect`). Test files are in `Hermit/HermitTests/`.

## Fastlane

```bash
cd Hermit
bundle exec fastlane beta      # TestFlight upload
bundle exec fastlane release   # App Store submission
```

Requires env vars in `fastlane/.env` — see `fastlane/.env.example`.

## Key Architecture Decisions

- **iOS 17 minimum**, portrait only, dark mode enforced
- **No Citadel dependency yet** — SSH is stubbed. The Citadel SPM reference was removed because version 0.26.0 doesn't exist. Re-add with correct version when implementing real SSH.
- **Data persistence**: JSON file in iCloud Drive ubiquitous container (`Documents/hermit-data.json`), local fallback if iCloud unavailable. Uses `NSFileCoordinator` for safe access and `NSMetadataQuery` to watch for remote changes.
- **Private keys**: stored in iOS Keychain via `KeychainManager`, never exported in data files.
- **Terminal**: xterm.js loaded from bundled `terminal.html` in a `WKWebView`. Swift-JS bridge via `WKScriptMessageHandler`.
- **Voice input**: Super Whisper integration via URL scheme callback (`hermit://voice-callback?text=...`), falls back to empty text editor if unavailable.

## Code Conventions

- SwiftUI views use `@Environment` for `DataStore` and `VoiceInputCoordinator` (both `@Observable`)
- Models are plain `Codable` structs
- No third-party dependencies in v1 (Citadel will be the first when SSH is implemented)
- JSON encoding/decoding uses `JSONEncoder.hermit` / `JSONDecoder.hermit` extensions with ISO 8601 dates

## File Layout

```
Hermit/Hermit/
├── App/HermitApp.swift              # @main, URL handling, About sheet on first launch
├── Models/                          # Host, Session, RibbonConfig, AppSettings
├── Storage/DataStore.swift          # JSON persistence + iCloud Drive sync
├── Storage/KeychainManager.swift    # Keychain CRUD for SSH keys
├── SSH/SSHConnectionManager.swift   # Connection state machine (stubbed)
├── SSH/TerminalBridge.swift         # WKWebView wrapper + WebViewStore
├── Voice/VoiceInputCoordinator.swift
├── Voice/SuperWhisperProvider.swift
├── Views/                           # SessionList, NewSession, NewHost, Terminal, VoiceInputModal, Settings, About
└── Resources/terminal.html          # xterm.js + fit addon
```

## Things to Know

- `PRODUCT_NAME` in pbxproj must be `$(TARGET_NAME)`, not empty — causes "missing bundle ID" on install
- `UILaunchScreen` dict must exist in Info.plist or the app renders at legacy iPhone resolution
- `SSHConnectionManager` echoes input back and shows placeholder text — replace with Citadel when ready
- The About view shows on first launch (tracked via `UserDefaults "hasSeenAbout"`), also accessible from Settings
- Adding new source files requires manual pbxproj edits (file ref, group, build phase) since there's no SPM package
