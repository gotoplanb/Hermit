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
# 1. Check for a connected iPhone and grab its UDID.
#    DEVICE_ID is a personal hardware identifier — keep it OUT of this public repo.
#    Either set it in fastlane/.env (gitignored) or auto-detect the connected phone:
xcrun xctrace list devices 2>&1 | grep "iPhone"
export DEVICE_ID=$(xcrun xctrace list devices 2>&1 | grep -v Simulator | grep -m1 iPhone | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}')

# 2a. If connected — build, install, and launch directly (fastest iteration)
cd Hermit
xcodebuild -project Hermit.xcodeproj -scheme Hermit \
  -destination "id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM_ID \
  build
xcrun devicectl device install app --device "$DEVICE_ID" \
  ~/Library/Developer/Xcode/DerivedData/Hermit-*/Build/Products/Debug-iphoneos/Hermit.app
xcrun devicectl device process launch --device "$DEVICE_ID" com.zeromissionllc.hermit

# 2b. If not connected — send to TestFlight
cd Hermit
bundle exec fastlane beta

# 3. Simulator (for UI development when device isn't needed)
xcodebuild -project Hermit.xcodeproj -scheme Hermit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Simulator Test Data

`.hermit-dev.json` in the project root (gitignored) holds host/session config plus a `devPrivateKeyPath`. It uses the same `BackupData` schema as `hermit-data.json` (`version`, `exportedAt`, `hosts`, `sessions`) with the extra `devPrivateKeyPath` field. To inject test data and the SSH key:

```bash
# 1. Get the simulator app data container
DOCS=$(xcrun simctl get_app_container booted com.zeromissionllc.hermit data)/Documents
mkdir -p "$DOCS"

# 2. Write the data file (strip the devPrivateKeyPath field)
python3 -c "
import json
with open('.hermit-dev.json') as f: d = json.load(f)
d.pop('devPrivateKeyPath', None)
with open('$DOCS/hermit-data.json', 'w') as f: json.dump(d, f, indent=2)
"

# 3. Copy the private key to the app's dev fallback location.
#    buildAuthMethod() tries the Keychain first (by the host's privateKeyRef),
#    then falls back to reading Documents/dev-ssh-key — so the simulator only
#    needs this file. NOTE: privateKeyRef must be non-empty or auth throws noKey.
KEY_PATH=$(python3 -c "
import json, os
with open('.hermit-dev.json') as f: d = json.load(f)
print(os.path.expanduser(d['devPrivateKeyPath']))
")
cp "$KEY_PATH" "$DOCS/dev-ssh-key"
chmod 600 "$DOCS/dev-ssh-key"

# 4. Relaunch the app
xcrun simctl terminate booted com.zeromissionllc.hermit
xcrun simctl launch booted com.zeromissionllc.hermit
```

The simulator shares the Mac's network, so it can reach any host the Mac can — including `127.0.0.1` (the Mac itself) and ngrok tunnels. Citadel is integrated, so this exercises **real** end-to-end SSH. The current `.hermit-dev.json` points at a loopback target (`dave@127.0.0.1:22`) that attaches to a local tmux session named `hermit`; it requires macOS Remote Login enabled and an authorized key at `~/.ssh/hermit_sim_mbp`.

### Driving the simulator UI (idb)

`simctl` can't tap, and AppleScript/cliclick need macOS Accessibility permission (not granted to the terminal), so use `idb` to tap/type/screenshot:

```bash
# One-time install: idb_companion (Homebrew) + fb-idb (persistent venv)
brew tap facebook/fb && brew trust facebook/fb && brew install idb-companion
python3 -m venv ~/.hermit-idb-venv && ~/.hermit-idb-venv/bin/pip install fb-idb

IDB=~/.hermit-idb-venv/bin/idb
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
$IDB ui describe-all --udid $UDID   # JSON of elements with AXLabel + frame (points)
$IDB ui tap <x> <y> --udid $UDID    # tap the center of a frame (iPhone 17 Pro screen is 402x874 pt)
```

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
- **SSH via Citadel** — real SSH lives in `SSHConnectionManager` using Citadel (the swift-nio-ssh / swift-crypto stack), added as an SPM dependency. It authenticates with an ed25519 or RSA key, opens a PTY, and runs `tmux new-session -As <name>`. `Package.resolved` is tracked in git.
- **Data persistence**: JSON file in iCloud Drive ubiquitous container (`Documents/hermit-data.json`), local fallback if iCloud unavailable. Uses `NSFileCoordinator` for safe access and `NSMetadataQuery` to watch for remote changes. iCloud is never used in the simulator (guarded by `#if !targetEnvironment(simulator)`), to avoid clobbering production data.
- **Private keys**: stored in the iOS Keychain via `KeychainManager`, never exported in data files. Simulator dev falls back to a plain `Documents/dev-ssh-key` file.
- **Terminal**: xterm.js loaded from bundled `terminal.html` in a `WKWebView`. Swift-JS bridge via `WKScriptMessageHandler`.
- **Voice input**: Super Whisper integration via URL scheme callback (`hermit://voice-callback?text=...`), falls back to empty text editor if unavailable.

## Code Conventions

- SwiftUI views use `@Environment` for `DataStore` and `VoiceInputCoordinator` (both `@Observable`)
- Models are plain `Codable` structs
- Citadel (with its swift-nio / swift-crypto transitive deps) is the one third-party dependency, added via SPM for SSH
- JSON encoding/decoding uses `JSONEncoder.hermit` / `JSONDecoder.hermit` extensions with ISO 8601 dates

## File Layout

```
Hermit/Hermit/
├── App/HermitApp.swift              # @main, URL handling, About sheet on first launch
├── Models/                          # Host, Session, RibbonConfig, AppSettings
├── Storage/DataStore.swift          # JSON persistence + iCloud Drive sync
├── Storage/KeychainManager.swift    # Keychain CRUD for SSH keys
├── SSH/SSHConnectionManager.swift   # Citadel SSH: key auth + PTY + tmux attach
├── SSH/TerminalBridge.swift         # WKWebView wrapper + WebViewStore
├── Voice/VoiceInputCoordinator.swift
├── Voice/SuperWhisperProvider.swift
├── Views/                           # SessionList, NewSession, NewHost, Terminal, VoiceInputModal, Settings, About
└── Resources/terminal.html          # xterm.js + fit addon
```

## Things to Know

- `PRODUCT_NAME` in pbxproj must be `$(TARGET_NAME)`, not empty — causes "missing bundle ID" on install
- `UILaunchScreen` dict must exist in Info.plist or the app renders at legacy iPhone resolution
- `SSHConnectionManager` loads the key from the Keychain (by `privateKeyRef`), falling back to `Documents/dev-ssh-key` for simulator dev; an empty `privateKeyRef` throws `SSHError.noKey`
- The custom ed25519 parser in `SSHConnectionManager` extracts the seed from an unencrypted OpenSSH private key by scanning for the second `ssh-ed25519` marker — encrypted keys are not supported
- The About view shows on first launch (tracked via `UserDefaults "hasSeenAbout"`), also accessible from Settings
- Adding new source files requires manual pbxproj edits (file ref, group, build phase) — the app target is a hand-maintained `.xcodeproj`; SPM is used only for dependencies, not app sources
