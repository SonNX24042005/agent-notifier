#!/usr/bin/env python3
"""
OpenAI Codex hook and notify handler for desktop notifications.
Cross-platform support for Linux and Windows.
"""

import json
import os
import subprocess
import sys
import re

IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

USER_HOME = os.environ.get("USERPROFILE") or os.environ.get("HOME") or os.path.expanduser("~")
MULTI_NOTIFY = os.path.join(USER_HOME, ".local", "bin", "multi-desktop-notify.py")
PYTHON3 = sys.executable or ("python" if IS_WINDOWS else "/usr/bin/python3")

SOUND_WARNING = "" if IS_WINDOWS else "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
SOUND_COMPLETE = "" if IS_WINDOWS else "/usr/share/sounds/freedesktop/stereo/complete.oga"


def clean_text(value, limit=400):
    text = " ".join(str(value or "").split())
    if not text:
        return "Codex cần bạn chú ý."
    if len(text) > limit:
        return text[: limit - 3] + "..."
    return text


def find_caller_tty(start_pid):
    """Linux only: Find the pts inherited by the agent."""
    if IS_WINDOWS:
        return ""
    pid = int(start_pid or 0)
    visited = set()

    while pid > 1 and pid not in visited:
        visited.add(pid)
        for fd in (0, 1, 2):
            try:
                tty_path = os.readlink(f"/proc/{pid}/fd/{fd}")
            except OSError:
                continue
            if tty_path.startswith("/dev/pts/"):
                return tty_path

        try:
            with open(f"/proc/{pid}/stat", "r") as stat_file:
                parent_pid = int(stat_file.read().split()[3])
        except (OSError, ValueError, IndexError):
            break
        pid = parent_pid

    return ""


def get_active_window_id():
    if IS_WINDOWS:
        try:
            import ctypes
            from ctypes import wintypes
            ctypes.windll.user32.GetForegroundWindow.restype = wintypes.HWND
            hwnd = ctypes.windll.user32.GetForegroundWindow()
            if hwnd:
                return str(hwnd)
        except Exception:
            pass
        return ""
    # Native Wayland capture belongs to the compositor adapter, not xdotool.
    if os.environ.get("WAYLAND_DISPLAY") or os.environ.get("XDG_SESSION_TYPE") == "wayland":
        return ""
    try:
        return subprocess.check_output(["xdotool", "getactivewindow"], stderr=subprocess.DEVNULL, timeout=0.75).decode().strip()
    except Exception:
        return ""


def send_notification(title, message, urgency="normal", sound_path=None, questions_json="", timeout=0, session_id="", event_type="info", event_id=""):
    msg = clean_text(message)
    caller_pid = os.getppid() if hasattr(os, "getppid") else 0
    caller_tty = find_caller_tty(os.getpid())
    terminal_screen = os.environ.get("GNOME_TERMINAL_SCREEN", "")
    project_hint = os.path.basename(os.getcwd().rstrip("/\\")) if os.getcwd() not in ["/", "\\"] else ""

    if os.path.exists(MULTI_NOTIFY):
        try:
            cmd = [
                PYTHON3,
                MULTI_NOTIFY,
                "--app-name=Codex",
                f"--title={title}",
                f"--message={msg}",
                f"--urgency={urgency}",
                f"--event-type={event_type}",
                f"--caller-pid={caller_pid}",
                f"--project-hint={project_hint}",
                f"--caller-tty={caller_tty}",
                f"--terminal-screen={terminal_screen}",
                f"--session-id={session_id}",
                f"--timeout={timeout}",
                f"--event-id={event_id}",
            ]
            if sound_path:
                cmd.append(f"--sound={sound_path}")
            if questions_json:
                cmd.append(f"--questions-json={questions_json}")

            creationflags = 0x08000000 if IS_WINDOWS else 0
            start_session = False if IS_WINDOWS else True
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=start_session,
                creationflags=creationflags,
            )
            return
        except Exception:
            pass


def payload_session_id(payload):
    """Use the conversation identity shared by SessionStart and legacy notify."""
    return (payload.get("session_id") or payload.get("session-id")
            or payload.get("thread-id") or payload.get("thread_id") or "")


def readable_hook_command(command):
    """Expose encoded PowerShell paths for ownership checks, without execution."""
    text = str(command)
    for match in re.finditer(r"-EncodedCommand\s+([A-Za-z0-9+/=]+)", str(command), re.I):
        try:
            import base64
            text += "\n" + base64.b64decode(match.group(1), validate=True).decode("utf-16-le")
        except (ValueError, UnicodeError):
            pass
    return text


def remove_notifier_hooks(entries):
    """Remove current and legacy notifier commands while retaining other handlers."""
    cleaned = []
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
            cleaned.append(entry)
            continue
        handlers = []
        for handler in entry["hooks"]:
            commands = [readable_hook_command(handler.get(key, "")) for key in ("command", "commandWindows")] if isinstance(handler, dict) else []
            owned = any(
                re.search(r'(?:^|[/\\\\])\.codex[/\\\\]notify\.py(?:[\s"\x27]|$)', str(command))
                or re.search(r'(?:^|[/\\\\\s"\x27])anoti(?:\.exe|\.cmd)?["\x27]?\s+hook\s+codex(?:\s|$)', str(command))
                for command in commands
            )
            if not owned:
                handlers.append(handler)
        if handlers or not entry["hooks"]:
            cleaned.append({**entry, "hooks": handlers})
    return cleaned


def configure_terminal_notifications(restore=False):
    """Manage only the terminal notification setting, preserving its original line."""
    from pathlib import Path
    path = Path(USER_HOME) / ".codex" / "config.toml"
    content = path.read_text(encoding="utf-8") if path.exists() else ""
    marker = "# ai-agent-notifier previous notifications: "
    lines = content.splitlines()
    for index, line in enumerate(lines):
        if line.startswith(marker):
            if restore:
                original = json.loads(line[len(marker):])
                if index + 1 < len(lines) and lines[index + 1] == "notifications = false":
                    lines[index:index + 2] = [original] if original else []
                    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return
    if restore:
        return
    # Validate before changing the file. Unusual TOML forms are left untouched.
    import tomllib
    parsed = tomllib.loads(content)
    section = None
    insertion = None
    previous = ""
    for index, line in enumerate(lines):
        header = re.match(r"^\s*\[([^\[\]]+)\]\s*(?:#.*)?$", line)
        if header:
            section = header.group(1).strip()
            if section == "tui":
                insertion = index + 1
        elif section == "tui" and re.match(r"^\s*notifications\s*=", line):
            tomllib.loads(line)  # Multiline values must not be partially replaced.
            insertion = index
            previous = line
            break
    if insertion is None:
        if "tui" in parsed:
            raise ValueError("Cannot safely edit inline or quoted tui settings")
        lines.extend(["", "[tui]"])
        insertion = len(lines)
    elif "notifications" in parsed.get("tui", {}) and not previous:
        raise ValueError("Cannot safely locate notifications setting")
    lines[insertion:insertion + bool(previous)] = [marker + json.dumps(previous), "notifications = false"]
    updated = "\n".join(lines) + "\n"
    tomllib.loads(updated)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(updated, encoding="utf-8")


def remove_legacy_notify(path):
    """Remove only our top-level legacy notify command, including multiline TOML."""
    from pathlib import Path
    import tomllib
    path = Path(path)
    if not path.exists():
        return
    content = path.read_text(encoding="utf-8")
    argv = tomllib.loads(content).get("notify")
    if not isinstance(argv, list):
        return
    command = " ".join(str(part) for part in argv)
    if remove_notifier_hooks([{"hooks": [{"command": command}]}]):
        return
    lines = content.splitlines(keepends=True)
    for start, line in enumerate(lines):
        if re.match(r"^\s*\[", line):
            break
        if not re.match(r"^\s*notify\s*=", line):
            continue
        for end in range(start + 1, len(lines) + 1):
            try:
                value = tomllib.loads("".join(lines[start:end]))
            except tomllib.TOMLDecodeError:
                continue
            if value.get("notify") == argv:
                updated = "".join(lines[:start] + lines[end:])
                tomllib.loads(updated)
                path.write_text(updated, encoding="utf-8")
                return
        raise ValueError("Cannot safely remove legacy Codex notify configuration")


def handle_completion(payload):
    # Legacy notify also fires for Codex's hidden title-generation thread.
    # Only the lifecycle Stop hook represents the visible conversation here.
    if payload.get("hook_event_name") != "Stop":
        return

    session_id = payload_session_id(payload)
    turn_id = payload.get("turn-id") or payload.get("turn_id") or ""
    send_notification(
        "Codex đã hoàn thành",
        "Codex đã hoàn thành lượt làm việc.",
        urgency="normal",
        sound_path=SOUND_COMPLETE,
        timeout=0,
        session_id=session_id,
        event_type="complete",
        event_id=f"codex:{session_id}:{turn_id}" if session_id and turn_id else "",
    )


def handle_hook(payload):
    event = payload.get("hook_event_name") or payload.get("type")
    session_id = payload_session_id(payload)

    if event in ("SessionStart", "session_start", "UserPromptSubmit"):
        if os.path.exists(MULTI_NOTIFY) and session_id:
            caller_win = get_active_window_id()
            caller_pid = os.getppid() if hasattr(os, "getppid") else 0
            project_hint = os.path.basename(os.getcwd().rstrip("/\\")) if os.getcwd() not in ["/", "\\"] else ""
            cmd = [
                PYTHON3, MULTI_NOTIFY,
                "--capture-session",
                "--app-name=Codex",
                f"--session-id={session_id}",
                f"--window-id={caller_win}",
                f"--caller-pid={caller_pid}",
                f"--project-hint={project_hint}",
            ]
            creationflags = 0x08000000 if IS_WINDOWS else 0
            # Complete capture while the hook's caller and focused window still
            # exist. A detached capture can run after the hook launcher exits.
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           creationflags=creationflags, timeout=4, check=False)
        return

    if event == "PermissionRequest":
        tool_name = payload.get("tool_name") or "công cụ"
        tool_input = payload.get("tool_input") or {}

        if isinstance(tool_input, dict):
            detail = (
                tool_input.get("description")
                or tool_input.get("command")
                or "Codex đang chờ bạn cấp quyền."
            )
            q_json = json.dumps(tool_input)
        else:
            detail = str(tool_input)
            q_json = ""

        send_notification(
            f"Codex cần cấp quyền: {tool_name}",
            detail,
            urgency="critical",
            sound_path=SOUND_WARNING,
            questions_json=q_json,
            session_id=session_id,
            event_type="permission",
        )
    elif event == "Stop":
        handle_completion(payload)


def trace_payload(payload, transport):
    """Record routing metadata for diagnosing duplicate deliveries."""
    try:
        import runpy
        engine = runpy.run_path(MULTI_NOTIFY)
        engine["record_notification_trace"](
            "codex-hook", transport=transport,
            event=payload.get("type") or payload.get("hook_event_name"),
            session=payload_session_id(payload),
            turn=payload.get("turn-id") or payload.get("turn_id") or "",
            caller=os.getppid(), client=payload.get("client") or "")
    except Exception:
        pass


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--configure-tui", "--restore-tui"):
        try:
            configure_terminal_notifications(restore=sys.argv[1] == "--restore-tui")
            return 0
        except Exception as exc:
            print(f"Could not update Codex terminal notifications: {exc}", file=sys.stderr)
            return 1
    try:
        if len(sys.argv) > 1 and sys.argv[1].strip():
            payload = json.loads(sys.argv[1])
            trace_payload(payload, "argv")
            handle_completion(payload)
            return 0

        if not sys.stdin.isatty():
            input_data = sys.stdin.read().strip()
            if input_data:
                payload = json.loads(input_data)
                trace_payload(payload, "stdin")
                handle_hook(payload)
                if payload.get("hook_event_name") == "Stop":
                    print("{}")
                return 0

    except Exception:
        pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
