# Hermit — iOS SSH Client Spec

## For Claude Code + XcodeBuild MCP Session

-----

## Overview

Hermit is a focused iOS SSH client built around a specific workflow: connecting to remote development machines, attaching to named tmux sessions, and interacting with Claude Code via configurable soft keys and voice input. It is not a general-purpose terminal emulator — it is a productivity tool for a developer who lives in tmux and Claude Code on a phone.

-----

## Architecture Decisions

|Concern           |Decision                                                          |
|------------------|------------------------------------------------------------------|
|Language          |Swift, SwiftUI                                                    |
|SSH Library       |Citadel (built on SwiftNIO SSH)                                   |
|Terminal rendering|xterm.js embedded in WKWebView                                    |
|Data persistence  |JSON file in app Documents directory, mirrored to iCloud Documents|
|Key storage       |iOS Keychain (one entry per Host)                                 |
|Minimum iOS       |iOS 17                                                            |
|Orientation       |Portrait only for v1                                              |

-----

## Data Model

### Host

Represents a remote machine's connection details. Acts as a template for Sessions.

```swift
struct Host: Codable, Identifiable {
    var id: UUID
    var displayName: String        // e.g. "Mac Mini"
    var hostname: String           // IP or domain
    var port: Int                  // default 22
    var username: String
    var privateKeyRef: String      // Keychain reference key
    var ribbonConfig: RibbonConfig
    var createdAt: Date
}
```

### Session

Represents a specific tmux session on a Host. This is the primary object the user interacts with.

```swift
struct Session: Codable, Identifiable {
    var id: UUID
    var displayName: String        // e.g. "claude-bosshardt"
    var hostID: UUID
    var tmuxSessionName: String?   // nil = no tmux, just raw shell
    var createdAt: Date
}
```

### RibbonConfig

Per-host configurable soft key definitions.

```swift
struct RibbonConfig: Codable {
    var buttons: [RibbonButton]    // ordered, rendered left to right
}

struct RibbonButton: Codable, Identifiable {
    var id: UUID
    var label: String              // display label or SF Symbol name
    var labelType: LabelType       // .text or .sfSymbol
    var action: ButtonAction
}

enum LabelType: String, Codable {
    case text
    case sfSymbol
}

enum ButtonAction: Codable {
    case sendString(String)        // sends raw string to terminal (e.g. "1\n", "2\n", "\u{1B}")
    case voiceInput                // opens voice input modal
}
```

### VoiceProviderConfig (App-level)

```swift
enum VoiceProvider: String, Codable {
    case none                      // opens modal empty
    case superWhisper              // invokes Super Whisper URL scheme
}

// Stored in UserDefaults
struct AppSettings: Codable {
    var voiceProvider: VoiceProvider
}
```

-----

## Default Ribbon Config

When creating a new Host, pre-populate with this default ribbon:

|Position|Label                        |Action                |
|--------|-----------------------------|----------------------|
|1       |`1`                          |sendString(`"1\n"`)   |
|2       |`2`                          |sendString(`"2\n"`)   |
|3       |`3`                          |sendString(`"3\n"`)   |
|4       |`esc`                        |sendString(`"\u{1B}"`)|
|5       |`mic` (SF Symbol: `mic.fill`)|voiceInput            |

-----

## Navigation Structure

```
App Launch
└── SessionListView (root)
    ├── [tap session] → TerminalView
    │   └── [voice button] → VoiceInputModal (sheet)
    ├── [add session] → NewSessionView
    │   └── [new host] → NewHostView
    ├── [edit session] → EditSessionView
    ├── [settings] → SettingsView
    │   ├── Voice provider selection
    │   └── iCloud backup/restore
    └── [long press session] → context menu (edit, delete)
```

-----

## Views

### SessionListView

- Standard iOS List grouped by Host
- Each section header = Host display name
- Each row = Session display name + tmux session name as subtitle
- Swipe left → Delete
- Long press → Edit / Delete context menu
- Top right: `+` button → NewSessionView
- Top left or settings gear: SettingsView
- No auto-connect on launch

### NewSessionView

- If Hosts exist: picker to select a Host (pre-fills all connection fields) or create new Host
- Fields: Display Name, tmux Session Name (optional)
- When Host selected, all Host fields shown read-only for confirmation
- Save → creates Session record

### NewHostView

- Fields: Display Name, Hostname, Port (default 22), Username
- Private key: paste PEM text → stored in Keychain
- Ribbon config: editable list of buttons with defaults pre-populated
- Save → creates Host record, returns to NewSessionView

### TerminalView

**Layout:**

```
┌─────────────────────────────────┐
│                                 │
│         xterm.js terminal       │
│         (~80% of screen)        │
│                                 │
│                                 │
├─────────────────────────────────┤
│  [1]  [2]  [3]  [esc]  [mic]   │  ← Ribbon (soft keys)
└─────────────────────────────────┘
```

- On appear: establish SSH connection, then run `tmux new-session -As <name>` if tmuxSessionName is set, otherwise raw shell
- Connection status indicator (subtle, top of terminal or navigation bar)
- Navigation bar back button disconnects SSH and returns to SessionListView
- Ribbon buttons rendered from Host's RibbonConfig
- Ribbon has a distinct background (system grouped background) to visually separate from terminal
- Ribbon buttons are large tap targets, rounded rect, system button style

**xterm.js Integration:**

- WKWebView loads a local HTML file bundled in the app containing xterm.js
- Swift ↔ JS bridge via `WKScriptMessageHandler` for:
  - Swift → JS: `writeToTerminal(data: String)` — sends SSH output to xterm
  - JS → Swift: user keystrokes captured and sent over SSH session
- xterm.js config: dark theme, monospace font, scrollback enabled

### VoiceInputModal

- Presented as `.sheet` from TerminalView when voice ribbon button tapped
- Contains:
  - Plain `TextEditor` (SwiftUI) pre-populated with transcribed text (or empty)
  - "Send" button — appends `\n` and writes to SSH session, dismisses sheet
  - "Cancel" button — dismisses without sending
- On appear: TextEditor is first responder (keyboard shows immediately)
- Append newline on send (configurable per-button in v2, hardcoded for v1)

### SettingsView

- Voice Provider: segmented or picker — None / Super Whisper
- iCloud Backup: "Export to iCloud Drive" button → saves `hermit-backup.json` to iCloud Documents
- iCloud Restore: "Import from iCloud Drive" button → file picker → merges or replaces local data (confirm dialog)

-----

## Super Whisper Integration

### URL Scheme Flow

1. User taps mic ribbon button
1. App checks `AppSettings.voiceProvider`
1. If `.superWhisper`:
- Check `UIApplication.shared.canOpenURL(superWhisperURL)`
- If available: open Super Whisper URL scheme with callback URL pointing back to Hermit
- Super Whisper transcribes, then opens Hermit callback URL with transcribed text as query parameter
- Hermit URL scheme handler receives text, opens VoiceInputModal pre-populated
- If NOT available (simulator or SW not installed): fall through to `.none` behavior
1. If `.none`:
- Open VoiceInputModal with empty TextEditor

### URL Scheme Registration

Register Hermit with a custom URL scheme in Info.plist, e.g. `hermit://`

Callback URL sent to Super Whisper: `hermit://voice-callback?text=<encoded-transcription>`

### AppDelegate / Scene URL Handling

Handle incoming URLs, extract `text` parameter, post notification or use shared state to trigger VoiceInputModal with text.

-----

## SSH Connection Management

- Use Citadel for SSH connections
- Auth: private key only (no password auth in v1)
- One active connection at a time (v1)
- On terminal view dismiss: close connection cleanly
- On connection failure: show alert with error message, return to session list
- Reconnect: user taps session again from list

-----

## iCloud Backup Format

Single JSON file: `hermit-backup.json`

```json
{
  "version": 1,
  "exportedAt": "ISO8601 timestamp",
  "hosts": [ ...Host records... ],
  "sessions": [ ...Session records... ]
}
```

Note: Private keys are NOT exported in backup (they live in Keychain). On restore, sessions referencing unknown hosts will prompt user to re-enter key material.

-----

## V1 Scope Boundary (Explicit)

**In v1:**

- SSH only (no Mosh)
- Private key auth only
- One active session at a time
- Super Whisper + None voice providers
- iCloud backup/restore
- Default ribbon + per-host ribbon customization (edit in NewHostView/EditHostView)
- tmux session attach or raw shell

**Explicitly out of v1:**

- Mosh support (data model has `protocol` field stub for v2)
- Word substitution dictionary (v2)
- iOS native dictation via SFSpeechRecognizer (v2)
- Multiple concurrent sessions
- Password authentication
- SFTP / file transfer
- iPad layout optimization

-----

## V2 Planning Notes (non-binding)

- **Word substitution dictionary**: app-level find/replace map applied to VoiceInputModal text before user sees it. UI to add/edit/delete substitution pairs in SettingsView.
- **Mosh**: add `protocol: ConnectionProtocol` (`.ssh` / `.mosh`) to Host model. Mosh requires server-side `mosh-server` and a suitable iOS Mosh library.
- **Per-button newline config**: `appendNewline: Bool` on `ButtonAction.sendString`

-----

## Testing Notes

- All UI and navigation fully testable in iOS Simulator
- SSH connection: cannot connect to real host from simulator without network config — use a mock SSH service or skip connection tests in simulator
- Super Whisper: not available in simulator — `canOpenURL` returns false, falls through to empty modal. This is the correct and tested behavior.
- Voice modal, send flow, ribbon rendering: fully testable in simulator
- Write unit tests for:
  - Data model Codable round-trips
  - RibbonConfig default generation
  - ButtonAction string encoding (especially ESC byte)
  - iCloud backup JSON serialization/deserialization
  - URL scheme callback parsing (`hermit://voice-callback?text=...`)

-----

## File / Project Structure (Suggested)

```
Hermit/
├── App/
│   ├── HermitApp.swift
│   └── AppDelegate.swift          # URL scheme handling
├── Models/
│   ├── Host.swift
│   ├── Session.swift
│   ├── RibbonConfig.swift
│   └── AppSettings.swift
├── Storage/
│   ├── DataStore.swift            # JSON persistence + iCloud
│   └── KeychainManager.swift
├── SSH/
│   ├── SSHConnectionManager.swift
│   └── TerminalBridge.swift       # WKWebView ↔ xterm.js bridge
├── Voice/
│   ├── VoiceInputCoordinator.swift
│   └── SuperWhisperProvider.swift
├── Views/
│   ├── SessionListView.swift
│   ├── NewSessionView.swift
│   ├── NewHostView.swift
│   ├── TerminalView.swift
│   ├── VoiceInputModal.swift
│   └── SettingsView.swift
├── Resources/
│   └── terminal.html              # xterm.js bundle
└── Tests/
    └── HermitTests/
        ├── ModelTests.swift
        ├── RibbonConfigTests.swift
        ├── DataStoreTests.swift
        └── URLSchemeTests.swift
```
