#!/usr/bin/env python3
"""
Claude Code lifecycle hook handler for desktop notifications.
Executes in 0ms, processes stdin JSON payload, and triggers multi-monitor popups.
Cross-platform support for Linux and Windows.
"""

import sys
import json
import os
import subprocess

IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

USER_HOME = os.environ.get("USERPROFILE") or os.environ.get("HOME") or os.path.expanduser("~")
MULTI_NOTIFY = os.path.join(USER_HOME, ".local", "bin", "multi-desktop-notify.py")
PYTHON3 = sys.executable or ("python" if IS_WINDOWS else "/usr/bin/python3")

SOUND_WARNING = "" if IS_WINDOWS else "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
SOUND_COMPLETE = "" if IS_WINDOWS else "/usr/share/sounds/freedesktop/stereo/complete.oga"

# 0. Read stdin
try:
    raw_payload = sys.stdin.read()
except Exception:
    raw_payload = ""

if not raw_payload.strip():
    sys.exit(0)

# 1. Ignore background initialization from agent2agents
if os.environ.get("AGENT2AGENTS_INITIALIZING") == "1" or os.environ.get("A2A_SILENT") == "1":
    sys.exit(0)

if "Initializing imported session history" in raw_payload:
    sys.exit(0)

try:
    data = json.loads(raw_payload)
except Exception:
    data = {}

event_name = data.get("hook_event_name") or data.get("event") or ""
notif_type = data.get("notification_type") or data.get("type") or data.get("matcher") or ""
session_id = data.get("session_id") or data.get("sessionID") or data.get("session") or ""
cwd_path = data.get("cwd") or os.getcwd()
project_hint = os.path.basename(cwd_path.rstrip("/\\")) if cwd_path else ""


def get_active_window_id():
    if IS_WINDOWS:
        try:
            import ctypes
            hwnd = ctypes.windll.user32.GetForegroundWindow()
            if hwnd:
                return str(hwnd)
        except Exception:
            pass
        return ""
    try:
        return subprocess.run(["xdotool", "getactivewindow"], capture_output=True, text=True, timeout=1).stdout.strip()
    except Exception:
        return ""


# 2. Early session capture (SessionStart)
if event_name == "SessionStart" or notif_type == "SessionStart":
    if os.path.exists(MULTI_NOTIFY):
        caller_win = get_active_window_id()
        cmd = [
            PYTHON3, MULTI_NOTIFY,
            "--capture-session",
            "--app-name=Claude Code",
            f"--session-id={session_id}",
            f"--window-id={caller_win}",
            f"--caller-pid={os.getppid()}",
            f"--project-hint={project_hint}",
        ]
        creationflags = 0x08000000 if IS_WINDOWS else 0
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           creationflags=creationflags, timeout=4, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass
    sys.exit(0)

# 3. Fast-path: Ignore idle_prompt and non-actionable notifications
if "idle_prompt" in raw_payload or "agent_needs_input" in raw_payload:
    sys.exit(0)

# 4. Check for genuine events (Question, Permission, Completion)
is_question = False
is_permission = False
is_completion = False
event_type = "info"

tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}

if "AskUserQuestion" in raw_payload or "ask_question" in raw_payload.lower():
    is_question = True
    event_type = "question"
elif "permission_prompt" in raw_payload or "PermissionRequest" in raw_payload:
    is_permission = True
    event_type = "permission"
elif "agent_completed" in raw_payload or '"Stop"' in raw_payload or event_name == "Stop":
    is_completion = True
    event_type = "complete"

if not is_question and not is_permission and not is_completion:
    sys.exit(0)

title = "Claude Code"
message = ""
urgency = "normal"
sound = ""
questions_json = ""
timeout = 0

if is_question:
    urgency = "critical"
    sound = SOUND_WARNING
    title = "Claude Code: Câu hỏi"
    questions_json = json.dumps(tool_input) if tool_input else ""
    if isinstance(tool_input, dict):
        if "questions" in tool_input and isinstance(tool_input["questions"], list):
            message = " | ".join(q.get("question") or q.get("title") or "" for q in tool_input["questions"] if isinstance(q, dict))
        elif "question" in tool_input:
            message = str(tool_input["question"])
        elif "prompt" in tool_input:
            message = str(tool_input["prompt"])
    if not message:
        message = data.get("message") or "Claude đang đặt câu hỏi cho bạn."

elif is_permission:
    urgency = "critical"
    sound = SOUND_WARNING
    title = f"Claude Code: Cần cấp quyền ({tool_name})" if tool_name else "Claude Code: Cần cấp quyền"
    if isinstance(tool_input, dict):
        message = tool_input.get("description") or tool_input.get("command") or data.get("message") or "Claude cần bạn cấp quyền thực thi."
    else:
        message = str(tool_input or data.get("message") or "Claude cần bạn cấp quyền thực thi.")

elif is_completion:
    urgency = "normal"
    sound = SOUND_COMPLETE
    title = "Claude Code: Hoàn thành"
    message = "Claude đã hoàn thành trả lời."

if not message:
    message = "Claude Code đang chờ bạn."

clean_msg = " ".join(message.split())
if len(clean_msg) > 400:
    clean_msg = clean_msg[:397] + "..."

if os.path.exists(MULTI_NOTIFY):
    cmd = [
        PYTHON3, MULTI_NOTIFY,
        "--app-name=Claude Code",
        f"--title={title}",
        f"--message={clean_msg}",
        f"--questions-json={questions_json}",
        f"--urgency={urgency}",
        f"--event-type={event_type}",
        f"--caller-pid={os.getppid()}",
        f"--project-hint={project_hint}",
        f"--session-id={session_id}",
        f"--timeout={timeout}",
    ]
    if sound:
        cmd.append(f"--sound={sound}")

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

sys.exit(0)
