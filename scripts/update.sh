#!/usr/bin/env bash

# Automated updater for AI Agent Multi-Monitor Desktop Notifier
set -e

USER_HOME="${HOME:-/home/$USER}"
LOCAL_BIN="$USER_HOME/.local/bin"
CLAUDE_HOOKS="$USER_HOME/.claude/hooks"
CODEX_DIR="$USER_HOME/.codex"
GEMINI_HOOKS="$USER_HOME/.gemini/hooks"
GEMINI_CONFIG="$USER_HOME/.gemini/config"
GNOME_EXTENSION_UUID="ai-agent-desktop-notifier@sonnx24042005"
GNOME_EXTENSION_DIR="$USER_HOME/.local/share/gnome-shell/extensions/$GNOME_EXTENSION_UUID"

REPO_URL="https://github.com/SonNX24042005/agent-notifier.git"

queue_gnome_extension_enable() {
    python3 - "$GNOME_EXTENSION_UUID" << 'PY'
import ast
import subprocess
import sys

uuid = sys.argv[1]
try:
    raw = subprocess.check_output(
        ["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
        stderr=subprocess.DEVNULL,
        text=True,
    ).strip()
    enabled = ast.literal_eval(raw) if raw and raw != "@as []" else []
    if uuid not in enabled:
        enabled.append(uuid)
        subprocess.run(
            ["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled)],
            check=False,
        )
except Exception:
    pass
PY
}

# Determine source directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [ -d "$CURRENT_DIR/.git" ] || [ -f "$CURRENT_DIR/bin/multi-desktop-notify.py" ]; then
    SCRIPT_DIR="$CURRENT_DIR"
elif [ -d "$CURRENT_DIR/../.git" ] || [ -f "$CURRENT_DIR/../bin/multi-desktop-notify.py" ]; then
    SCRIPT_DIR="$(cd "$CURRENT_DIR/.." && pwd)"
else
    echo "=== 1. Downloading latest release from GitHub ==="
    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR/repo" &>/dev/null || {
        echo "Error: Failed to clone repository $REPO_URL"
        exit 1
    }
    SCRIPT_DIR="$TEMP_DIR/repo"
fi

if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "=== 1. Pulling latest updates from Git repository ==="
    (cd "$SCRIPT_DIR" && git pull --rebase origin master 2>/dev/null || git pull --rebase 2>/dev/null || true)
else
    echo "=== 1. Updating from local source ==="
fi

if ! python3 -c "import gi; gi.require_version('Atspi', '2.0'); from gi.repository import Atspi" &>/dev/null; then
    echo "Warning: AT-SPI typelib is missing; install gir1.2-atspi-2.0 for Wayland auto-dismiss detection."
fi

echo "=== 2. Updating notification engine and hooks ==="
mkdir -p "$LOCAL_BIN" "$CLAUDE_HOOKS" "$CODEX_DIR" "$GEMINI_HOOKS" "$GEMINI_CONFIG"

cp "$SCRIPT_DIR/bin/multi-desktop-notify.py" "$LOCAL_BIN/multi-desktop-notify.py"
chmod +x "$LOCAL_BIN/multi-desktop-notify.py"

cp "$SCRIPT_DIR/hooks/claude-notify.sh" "$CLAUDE_HOOKS/notify-input.sh"
chmod +x "$CLAUDE_HOOKS/notify-input.sh"

if [ -f "$SCRIPT_DIR/hooks/claude-notify.py" ]; then
    cp "$SCRIPT_DIR/hooks/claude-notify.py" "$CLAUDE_HOOKS/notify-claude.py"
    chmod +x "$CLAUDE_HOOKS/notify-claude.py"
fi

cp "$SCRIPT_DIR/hooks/codex-notify.py" "$CODEX_DIR/notify.py"
chmod +x "$CODEX_DIR/notify.py"

cp "$SCRIPT_DIR/hooks/antigravity-notify.sh" "$GEMINI_HOOKS/notify-antigravity.sh"
chmod +x "$GEMINI_HOOKS/notify-antigravity.sh"

if [ -f "$SCRIPT_DIR/hooks/antigravity-notify.py" ]; then
    cp "$SCRIPT_DIR/hooks/antigravity-notify.py" "$GEMINI_HOOKS/notify-antigravity.py"
    chmod +x "$GEMINI_HOOKS/notify-antigravity.py"
fi

if [ -f "$SCRIPT_DIR/bin/anoti" ]; then
    cp "$SCRIPT_DIR/bin/anoti" "$LOCAL_BIN/anoti"
    chmod +x "$LOCAL_BIN/anoti"
fi

if command -v gnome-shell &>/dev/null && [ -d "$SCRIPT_DIR/gnome-shell-extension" ]; then
    gnome-extensions disable "$GNOME_EXTENSION_UUID" &>/dev/null || true
    mkdir -p "$GNOME_EXTENSION_DIR"
    cp "$SCRIPT_DIR/gnome-shell-extension/metadata.json" "$GNOME_EXTENSION_DIR/metadata.json"
    GNOME_SHELL_MAJOR="$(gnome-shell --version 2>/dev/null | sed -n 's/.* \([0-9][0-9]*\)\..*/\1/p')"
    if [ -n "$GNOME_SHELL_MAJOR" ] && [ "$GNOME_SHELL_MAJOR" -lt 45 ]; then
        cp "$SCRIPT_DIR/gnome-shell-extension/extension-legacy.js" "$GNOME_EXTENSION_DIR/extension.js"
    else
        cp "$SCRIPT_DIR/gnome-shell-extension/extension-modern.js" "$GNOME_EXTENSION_DIR/extension.js"
    fi
    if command -v gnome-extensions &>/dev/null; then
        if gnome-extensions enable "$GNOME_EXTENSION_UUID" &>/dev/null; then
            GNOME_DESIRED_VERSION="$(sed -n 's/.*"version":[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$GNOME_EXTENSION_DIR/metadata.json" | head -n 1)"
            GNOME_RUNTIME_VERSION="$(gnome-extensions info "$GNOME_EXTENSION_UUID" 2>/dev/null | sed -n 's/^[[:space:]]*Version:[[:space:]]*//p' | head -n 1)"
            if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] && [ -n "$GNOME_DESIRED_VERSION" ] && [ "$GNOME_RUNTIME_VERSION" != "$GNOME_DESIRED_VERSION" ]; then
                echo "Warning: Log out and back in once to load the updated GNOME Shell window focus adapter."
            else
                echo "✓ Reloaded GNOME Shell window focus adapter"
            fi
        else
            queue_gnome_extension_enable
            echo "Warning: Log out and back in once to load the GNOME Shell window focus adapter."
        fi
    fi
fi

echo "=== 3. Syncing configuration files safely ==="
python3 << 'EOF'
import json, os

USER_HOME = os.environ.get("HOME") or os.path.expanduser("~")

# 1. Claude Code (~/.claude/settings.json)
claude_path = os.path.join(USER_HOME, ".claude", "settings.json")
if os.path.exists(claude_path):
    try:
        with open(claude_path, "r") as f:
            cdata = json.load(f)
    except Exception:
        cdata = {}
    if not isinstance(cdata, dict):
        cdata = {}
    if "hooks" not in cdata or not isinstance(cdata["hooks"], dict):
        cdata["hooks"] = {}

    claude_hook_cmd = f"{USER_HOME}/.claude/hooks/notify-input.sh"
    target_hooks = {
        "SessionStart": [{"hooks": [{"type": "command", "command": claude_hook_cmd}]}],
        "PreToolUse": [{"matcher": "AskUserQuestion", "hooks": [{"type": "command", "command": claude_hook_cmd}]}],
        "Notification": [
            {"matcher": "permission_prompt", "hooks": [{"type": "command", "command": claude_hook_cmd}]},
            {"matcher": "agent_completed", "hooks": [{"type": "command", "command": claude_hook_cmd}]}
        ],
        "Stop": [{"hooks": [{"type": "command", "command": claude_hook_cmd}]}]
    }

    for event, new_entries in target_hooks.items():
        if event not in cdata["hooks"] or not isinstance(cdata["hooks"][event], list):
            cdata["hooks"][event] = []
        filtered = [item for item in cdata["hooks"][event] if "notify-input.sh" not in json.dumps(item) and "notify-claude.py" not in json.dumps(item) and "ai-agent-desktop-notifier" not in json.dumps(item)]
        filtered.extend(new_entries)
        cdata["hooks"][event] = filtered

    with open(claude_path, "w") as f:
        json.dump(cdata, f, indent=2)
    print("✓ Synced Claude Code settings.json (preserved other hooks)")

# 2. Codex (~/.codex/config.toml & ~/.codex/hooks.json)
codex_cfg = os.path.join(USER_HOME, ".codex", "config.toml")
import runpy
runpy.run_path(os.path.join(USER_HOME, ".codex", "notify.py"))["remove_legacy_notify"](codex_cfg)

codex_hooks = os.path.join(USER_HOME, ".codex", "hooks.json")
data_hooks = {"description": "Ubuntu desktop notifications for Codex", "hooks": {}}
if os.path.exists(codex_hooks):
    try:
        with open(codex_hooks, "r") as f:
            data_hooks = json.load(f)
    except Exception:
        pass
if not isinstance(data_hooks, dict):
    data_hooks = {"description": "Ubuntu desktop notifications for Codex", "hooks": {}}
if "hooks" not in data_hooks or not isinstance(data_hooks["hooks"], dict):
    data_hooks["hooks"] = {}

perm_h = {
    "hooks": [
        {
            "type": "command",
            "command": f"/usr/bin/python3 {USER_HOME}/.codex/notify.py",
            "timeout": 5,
            "statusMessage": "Sending Ubuntu notification"
        }
    ]
}
for event_name in ("PermissionRequest", "SessionStart", "UserPromptSubmit", "Stop"):
    existing = data_hooks["hooks"].get(event_name, [])
    if not isinstance(existing, list):
        existing = []
    import runpy
    clean_hooks = runpy.run_path(os.path.join(USER_HOME, ".codex", "notify.py"))["remove_notifier_hooks"]
    filtered = clean_hooks(existing)
    filtered.append(perm_h)
    data_hooks["hooks"][event_name] = filtered

with open(codex_hooks, "w") as f:
    json.dump(data_hooks, f, indent=2)
print("✓ Synced Codex hooks.json")

# 3. Antigravity (~/.gemini/settings.json & ~/.gemini/config/hooks.json)
hook_cmd = f"{USER_HOME}/.gemini/hooks/notify-antigravity.sh"

gemini_settings_file = os.path.join(USER_HOME, ".gemini", "settings.json")
if os.path.exists(gemini_settings_file):
    try:
        with open(gemini_settings_file, "r") as f:
            sdata = json.load(f)
    except Exception:
        sdata = {}
    if not isinstance(sdata, dict):
        sdata = {}
    if "hooks" not in sdata or not isinstance(sdata["hooks"], dict):
        sdata["hooks"] = {}

    target_gemini_hooks = {
        "PreInvocation": [{"type": "command", "command": hook_cmd, "timeout": 5}],
        "PreToolUse": [{"matcher": "ask_question|AskUserQuestion", "hooks": [{"type": "command", "command": hook_cmd, "timeout": 10}]}],
        "Stop": [{"type": "command", "command": hook_cmd, "timeout": 10}],
        "Notification": [{"matcher": "permission_prompt|idle_prompt|agent_needs_input|agent_completed", "hooks": [{"type": "command", "command": hook_cmd, "timeout": 10}]}],
    }

    for evt, entries in target_gemini_hooks.items():
        if evt not in sdata["hooks"] or not isinstance(sdata["hooks"][evt], list):
            sdata["hooks"][evt] = []
        filtered = [item for item in sdata["hooks"][evt] if "notify-antigravity" not in json.dumps(item)]
        filtered.extend(entries)
        sdata["hooks"][evt] = filtered

    with open(gemini_settings_file, "w") as f:
        json.dump(sdata, f, indent=2)
    print("✓ Synced Antigravity settings.json (preserved other hooks)")

gemini_config_dir = os.path.join(USER_HOME, ".gemini", "config")
os.makedirs(gemini_config_dir, exist_ok=True)
gemini_hooks_file = os.path.join(gemini_config_dir, "hooks.json")

gdata = {}
if os.path.exists(gemini_hooks_file):
    try:
        with open(gemini_hooks_file, "r") as f:
            gdata = json.load(f)
    except Exception:
        gdata = {}
if not isinstance(gdata, dict):
    gdata = {}

gdata["desktop-notifier"] = {
    "PreInvocation": [
        {
            "type": "command",
            "command": hook_cmd,
            "timeout": 5
        }
    ],
    "PreToolUse": [
        {
            "matcher": "ask_question|AskUserQuestion",
            "hooks": [
                {
                    "type": "command",
                    "command": hook_cmd,
                    "timeout": 10
                }
            ]
        }
    ],
    "Stop": [
        {
            "type": "command",
            "command": hook_cmd,
            "timeout": 10
        }
    ]
}

with open(gemini_hooks_file, "w") as f:
    json.dump(gdata, f, indent=2)
print("✓ Synced Antigravity hooks.json (~/.gemini/config/hooks.json)")

cli_hooks_file = os.path.join(USER_HOME, ".gemini", "antigravity-cli", "hooks.json")
cli_data = {}
if os.path.exists(cli_hooks_file):
    with open(cli_hooks_file, encoding="utf-8") as f:
        cli_data = json.load(f)
cli_data["desktop-notifier"] = gdata["desktop-notifier"]
os.makedirs(os.path.dirname(cli_hooks_file), exist_ok=True)
with open(cli_hooks_file, "w", encoding="utf-8") as f:
    json.dump(cli_data, f, indent=2)

# 4. Sync GNOME global shortcut (Alt+Q)
try:
    import subprocess, ast
    anoti_bin = os.path.join(USER_HOME, ".local", "bin", "anoti")
    target_path = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/anoti-focus/"

    try:
        out = subprocess.check_output(["gsettings", "get", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings"], stderr=subprocess.DEVNULL).decode().strip()
        bindings = ast.literal_eval(out) if out and out != "@as []" else []
    except Exception:
        bindings = []

    if target_path not in bindings:
        bindings.append(target_path)
        subprocess.run(["gsettings", "set", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings", str(bindings)], check=False)

    schema_id = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{target_path}"
    subprocess.run(["gsettings", "set", schema_id, "name", "Focus AI Agent (anoti)"], check=False)
    subprocess.run(["gsettings", "set", schema_id, "command", f"{anoti_bin} focus"], check=False)
    subprocess.run(["gsettings", "set", schema_id, "binding", "<Alt>q"], check=False)
    print("✓ Synced Alt+Q global shortcut for anoti focus")
except Exception:
    pass
EOF

python3 "$CODEX_DIR/notify.py" --configure-tui || echo "Warning: Configure Codex tui.notifications manually to avoid duplicate terminal notifications."

echo "=== 4. Update Complete! ==="
"$LOCAL_BIN/multi-desktop-notify.py" \
    --app-name="AI Agent Notifier" \
    --title="Cập nhật thành công!" \
    --message="Phiên bản mới nhất và phím tắt Alt+Q đã được đồng bộ vào hệ thống." \
    --sound="/usr/share/sounds/freedesktop/stereo/complete.oga" \
    --timeout=4
