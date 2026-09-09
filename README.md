# AI agent desktop notifier (anoti)

[Tiếng Việt](README_vi.md)

Multi-monitor desktop notification overlay with automatic window focus for AI coding agents: **Claude Code**, **Google Antigravity**, and **OpenAI Codex** on both **Linux** (X11 / GNOME) and **Windows** (10 / 11).

---

## Key features

- **Multi-monitor overlay**: Automatically detects all connected displays (Xinerama/XRandR on Linux, Win32 Monitor API on Windows), rendering dark-slate floating banners across monitors with an audible system alert.
- **Windows support**: Native Tkinter floating overlay across displays, persisting until handled and maintaining verified source window identity. Windows toast notifications are used only as a fallback when the overlay cannot initialize.
- **Automatic workspace switching and verified identity focus**:
  - **Automatic workspace switching**: Detects the workspace containing the application window and switches to it before focusing (Linux).
  - **Bypasses foreground lock (Windows)**: Employs `AttachThreadInput` and `SetForegroundWindow` via Win32 API to bring the target terminal or IDE window to the foreground immediately without taskbar flashing.
  - **Tier 1 (Session cache)**: Looks up cached window IDs stored at session start (`SessionStart`/`PreInvocation`) with window validity and owner PID verification to prevent stale handle reuse. Window PID is tracked separately from short-lived hook caller PIDs, so the focus button, auto-dismiss, and `Alt+Q` remain functional after hook execution on X11.
  - **Tier 2 (Process tree ancestry)**: Traverses parent PID ancestry (`/proc/{pid}/stat` on Linux or Win32 Toolhelp snapshot on Windows) matched with project directory hints to resolve the corresponding terminal or IDE window.
  - **Tier 3 (Direct window ID)**: Validates explicit `--window-id` arguments against active developer windows.
  - **Tier 4 (GNOME Terminal on Wayland)**: Uses a D-Bus adapter when process relationships prove the agent runs inside GNOME Terminal.
  - **Safe fallback**: Yields no target when evidence is ambiguous, preventing arbitrary window focus.
  - **Native Wayland focus**: On GNOME Shell, the extension captures a unique token for the focused window at session start, combining the Shell session namespace with a stable window sequence to distinguish multiple Codex or Antigravity instances under the same process.
- **Per-window notification queue**: Each window retains only its latest notification, even when multiple agents or sessions run concurrently within that window. Notifications are stacked newest first; dismissing or resolving the active notification automatically displays the next pending item.
- **Auto-dismiss upon focus**: Verifies the window handle or token rather than inferring state from PID or process name. Focusing any window with a pending notification immediately clears its entry, automatically closing active popups and advancing the queue.
- **Persistent until resolved**: Overlays do not expire prematurely when `--timeout=0`. Stored items are not pruned merely by age; closing the popup, focusing the source window, or successfully switching to it resolves the item.
- **Source-aware deduplication**: Message content is hashed alongside source identity, preventing duplicate notifications from the same window while preserving distinct notifications from separate windows sending identical messages.
- **Multi-channel webhooks**: Relays notifications to mobile devices or team chat channels (Slack, Discord, Bark iOS, ntfy, Feishu, DingTalk) when you step away from your workstation.
- **Interactive controls and shortcuts**:
  - **Global shortcut (`Alt + Q`)**: Switch instantly from anywhere in your workflow (browser, documents, editor) to the AI agent window awaiting input via `Alt + Q` (Linux) or `anoti focus`. Shortcuts, CLI commands, and popup buttons share the same queue identity.
  - **Popup interaction**: Click *"Go to window (Alt+Q)"*, or use keyboard shortcuts `Enter` / `Space` / `F` to focus the window, and `Esc` / `Q` to dismiss. The button displays *"Switching..."* while focus requests execute asynchronously, re-enabling if the target window cannot be resolved.
- **`anoti` CLI utility**: A unified command-line tool to focus windows, update, inspect system health, trigger test notifications, and uninstall from anywhere on your system.

---

## Supported AI agents

1. **Claude Code** (integrated via lifecycle hooks in `~/.claude/settings.json`: `SessionStart`, `PreToolUse: AskUserQuestion`, `Notification`, `Stop`).
2. **OpenAI Codex** (integrated via `SessionStart`, `UserPromptSubmit`, `PermissionRequest`, `Stop` hooks in `~/.codex/hooks.json`; verified with Codex 0.153.4).
3. **Google Antigravity** (integrated via `desktop-notifier` lifecycle hook in `~/.gemini/config/hooks.json` and `~/.gemini/antigravity-cli/hooks.json` for the `agy` CLI; installer and updater configure both on Linux and Windows).

During upgrades, the installer automatically migrates legacy Codex hooks (`anoti hook codex`) to the current adapter to prevent `Hook failed` errors with exit code `2`. Non-notifier hooks are preserved.

On Windows, verified capture stores a unique token in window properties to distinguish multiple Terminal windows sharing a PID, even when window titles change or lack project names. Tokens are discarded when the window closes. If property writes are restricted, the notifier falls back to conservative title and PID checks. After updating, restart `agy` sessions; for Codex, submit a prompt from the source window to refresh older cache entries. `anoti status` reports Antigravity and Antigravity CLI states independently.

Windows hooks use PowerShell `-EncodedCommand` to dispatch Python adapters through CMD without quote escaping issues. Payloads are delivered via UTF-8 stdin without requiring switching from CMD to PowerShell. Restart Codex or Antigravity sessions after hook configuration changes to load new commands.

For agents running in Windows Terminal or CMD, the engine retrieves the HWND from the console of `codex.exe`, `agy.exe`, or `claude.exe` and its console owner, correctly identifying secondary Terminal windows sharing a PID or detached from the CMD process tree. Hook temporary consoles are excluded. If the backend cannot resolve a visible owner, the engine relies on cached PIDs without guessing among ambiguous candidates.

Codex 0.153.4 emits legacy `notify` events during background title generation, causing extraneous notifications on the first turn. The notifier relies on `Stop` events to filter these out. `UserPromptSubmit` re-captures the source window if initial session capture missed, distinguishing multiple windows under the same terminal via unique tokens. When an exact window is not yet confirmed, notifications persist and do not dismiss simply because an unrelated window in the same process gained focus.

Resolved window notifications supersede unverified prior items from the same session, preventing lingering unresolvable notifications.

On GNOME Wayland, extension version 4 identifies `org.gnome.Terminal`, and the Codex hook captures the window synchronously at session start. After upgrading the extension, log out and log back in if the installer indicates an active older runtime, then reopen Codex sessions to replace legacy application identities with per-window tokens. Codex uses thread and turn identifiers to deduplicate re-delivered events. A diagnostic circular buffer of 200 events is maintained in `notification_trace.json` within the runtime directory, containing routing metadata only.

On X11, verified capture uses window-attached tokens, ensuring title modifications or shared PIDs across terminals do not disable focus buttons or auto-dismiss functionality. Capture hooks wait for completion before returning to preserve caller ancestry. Reopen agents after updates to re-capture existing sessions; Codex and Antigravity also re-capture on turn start.

Real X11 test suite: `NOTIFIER_TEST_X11=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_x11_window_regressions.py' -v`. Launches temporary WezTerm and GNOME Terminal instances, tests simulated adapter payloads, dynamic title changes, focus, auto-dismiss, and queue stacks without making model calls. Automatically cleans up test artifacts.

Real WezTerm integration tests: `NOTIFIER_TEST_WEZTERM=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_codex_window_regressions.py' -v`. Creates temporary WezTerm windows sharing PID and title, verifying fallback capture, stack B -> A transitions, and turn handling in window A. Cleans up test windows and runtime automatically.

Real Wayland integration tests (creates and focuses temporary windows under a single process): `NOTIFIER_TEST_WAYLAND=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_codex_window_regressions.py' -v`. Skipped by default; runs only in Linux Wayland sessions with GTK3 and an active GNOME Shell extension.

The installer disables `tui.notifications` in Codex configuration so terminals such as WezTerm do not emit redundant banners alongside the overlay. Restart Codex after installation for settings to take effect. Previous values are preserved as comments in `config.toml` and restored upon uninstall if unmodified. Completion notifications rely on `Stop` events with `session_id` and `turn_id`. Legacy notify hooks are pruned by the installer; the adapter ignores deprecated payloads from lingering Codex processes. Reopening Codex loads the updated hooks.

---

## Quick installation

### Windows (PowerShell)

Open **PowerShell** (or Windows Terminal) and run:

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/install.ps1 | iex
```

### Linux (Ubuntu / Debian / Fedora / Arch)

Open a **terminal** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/install.sh | bash
```

After installation, reload your VS Code / IDE window:
> `Ctrl + Shift + P` -> `Developer: Reload Window`

---

## `anoti` CLI command reference

Once installed, `anoti` can be invoked from any directory (supported across PowerShell, CMD, Git Bash, and Linux bash/zsh):

```bash
# 1. Focus the AI agent window waiting for user input
anoti focus
# or using the short flag:
anoti -f

# 2. Update the notification system to the latest release
anoti update
# or using the short flag:
anoti -u

# 3. Diagnose system health and verify version synchronization
anoti doctor
# or using alias:
anoti doc

# 4. Check integration status for all supported agents
anoti status
# or:
anoti -s

# 5. Send a test notification banner across all monitors
anoti test
# or:
anoti -t

# 6. View or configure webhook endpoints (Slack, Discord, Bark, ntfy, etc.)
anoti config
# or:
anoti -c

# 7. Send a custom notification from terminal or shell scripts
anoti --title "Build finished" --message "Compilation completed in 45 seconds"

# 8. Cleanly uninstall the notification system and restore configurations
anoti uninstall
```

---

## Remote update

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/update.ps1 | iex
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/update.sh | bash
```

---

## Remote uninstall

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/uninstall.ps1 | iex
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/uninstall.sh | bash
```

---

## Webhook configuration (optional)

To receive notifications on mobile devices or team chat channels when away from your desk, configure `~/.config/ai-agent-notifier/config.json` (or execute `anoti config`):

```json
{
  "webhooks": {
    "slack": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "discord": "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL",
    "bark": "https://api.day.app/YOUR_KEY",
    "ntfy": "https://ntfy.sh/your_topic",
    "feishu": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_KEY",
    "dingtalk": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  }
}
```

---

## Project structure

Developer and agent documentation: [Contributing guide](CONTRIBUTING.md).

```
ai-agent-desktop-notifier/
├── bin/
│   ├── anoti                     # Cross-platform CLI manager
│   ├── anoti.cmd                 # Wrapper for Windows Command Prompt
│   ├── anoti.ps1                 # Wrapper for PowerShell
│   └── multi-desktop-notify.py   # Multi-monitor popup engine, toast, and window focus
│   ├── architecture.md           # Architecture design and extension guide
│   └── windows-guide.md          # Guide for Windows users
├── hooks/
│   ├── claude-notify.py          # Claude Code lifecycle hook script (cross-platform)
│   ├── claude-notify.sh          # Claude Code lifecycle hook script (Linux)
│   ├── codex-notify.py           # OpenAI Codex notification script (cross-platform)
│   ├── antigravity-notify.py     # Google Antigravity hook script (cross-platform)
│   └── antigravity-notify.sh     # Google Antigravity hook script (Linux)
├── gnome-shell-extension/        # Native Wayland window focus adapter for GNOME Shell
├── install.ps1                   # Automated installation script for Windows (PowerShell)
├── install.sh                    # Automated installation script for Linux (Bash)
├── update.ps1                    # Update script for Windows
├── update.sh                     # Update script for Linux
├── uninstall.ps1                 # Clean uninstallation script for Windows
├── uninstall.sh                  # Clean uninstallation script for Linux
├── CONTRIBUTING.md               # Open-source contribution guidelines
├── README.md                     # Main documentation (English)
├── README_vi.md                  # Main documentation (Vietnamese)
├── .gitignore
└── LICENSE
```

---

## License

Distributed under the [MIT License](LICENSE).
