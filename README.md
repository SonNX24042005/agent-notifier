# AI agent desktop notifier (anoti)

[Tiếng Việt](README_vi.md)

Multi-monitor desktop notification overlay with 1-click window focus for AI coding agents (**Claude Code**, **Google Antigravity**, and **OpenAI Codex**) on **Linux** (X11 / GNOME) and **Windows** (10 / 11).

Never miss an AI agent asking for permission, waiting for input, or completing a task while you work in other windows.

---

## Key features

- **Multi-monitor overlay**: Displays floating notification banners across all connected monitors with an audible alert, ensuring you notice it regardless of which screen you are looking at.
- **1-click window focus (`Alt + Q`)**: Click *"Go to window"* or press `Alt + Q` (or run `anoti focus`) to switch immediately to the terminal or IDE window where the agent is waiting.
- **Auto-dismiss on focus**: Automatically closes the popup banner as soon as you focus the agent's window.
- **Queue management**: Stacks notifications when multiple agents or tasks are running. Resolving one notification immediately shows the next pending one.
- **Mobile and chat webhooks**: Optionally relays notifications to your phone or team channels (Slack, Discord, Bark, ntfy, Lark/Feishu, DingTalk) when you step away from your computer.
- **Cross-platform**: Works seamlessly on both Linux (Ubuntu, Debian, Fedora, Arch) and Windows (10, 11).

---

## Supported AI agents

- **Claude Code**
- **Google Antigravity** (`agy`)
- **OpenAI Codex**

Hooks are automatically configured during installation or can be refreshed at any time using `anoti setup-hooks`.

---

## Quick installation

### Windows

- **Option 1: Graphical installer (recommended)**:
  Download and run `anoti-setup.exe` from [GitHub Releases](https://github.com/SonNX24042005/agent-notifier/releases). The installer automatically sets up the application and agent hooks.

- **Option 2: One-line PowerShell command**:
  Run the following in PowerShell:
  ```powershell
  irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/scripts/install.ps1 | iex
  ```

### Linux (Ubuntu / Debian / Fedora / Arch)

- **Option 1: Debian / Ubuntu package (recommended)**:
  Download the latest `.deb` package from [GitHub Releases](https://github.com/SonNX24042005/agent-notifier/releases) and install:
  ```bash
  sudo apt install ./ai-agent-desktop-notifier_1.3.1_all.deb
  anoti setup-hooks
  ```

- **Option 2: One-line terminal command**:
  Run the following in your terminal:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/scripts/install.sh | bash
  ```

After installation, reload your editor window (e.g., in VS Code press `Ctrl + Shift + P` and choose `Developer: Reload Window`).

---

## Usage and CLI commands

The `anoti` command-line utility is available system-wide after installation:

```bash
# Focus the agent window awaiting input
anoti focus

# Set up or update hooks for all supported agents
anoti setup-hooks

# Send a test notification across monitors
anoti test

# Check integration status for AI agents
anoti status

# Run system health diagnostics
anoti doctor

# Open webhook configuration
anoti config

# Update to the latest version
anoti update

# Cleanly uninstall
anoti uninstall
```

### Shortcuts on the popup banner

- `Enter` / `Space` / `F`: Focus the target window.
- `Esc` / `Q`: Dismiss the current notification.
- Global shortcut: `Alt + Q` (Linux) jumps directly to the waiting agent window.

---

## Webhook setup (optional)

To receive notifications on mobile devices or chat apps when away from your desk, configure webhooks via `anoti config` or by editing `~/.config/ai-agent-notifier/config.json`:

```json
{
  "webhooks": {
    "slack": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "discord": "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL",
    "bark": "https://api.day.app/YOUR_KEY",
    "ntfy": "https://ntfy.sh/your_topic"
  }
}
```

---

## License

Distributed under the [MIT License](LICENSE).
