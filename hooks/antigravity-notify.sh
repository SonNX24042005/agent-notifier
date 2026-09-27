#!/usr/bin/env python3
"""
Antigravity lifecycle hook handler for desktop notifications.
Executes in 0ms, logs diagnostic payload, and triggers multi-monitor popups.
Cross-platform support for Linux and Windows.
"""

import sys
import json
import os
import sqlite3
import tempfile
import subprocess
from pathlib import Path

IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

USER_HOME = os.environ.get("USERPROFILE") or os.environ.get("HOME") or os.path.expanduser("~")
MULTI_NOTIFY = os.path.join(USER_HOME, ".local", "bin", "multi-desktop-notify.py")
PYTHON3 = sys.executable or ("python" if IS_WINDOWS else "/usr/bin/python3")

# 0. Read stdin
try:
    raw_payload = sys.stdin.read()
except Exception:
    raw_payload = ""

if not raw_payload.strip():
    print("{}")
    sys.exit(0)

try:
    data = json.loads(raw_payload)
except Exception:
    data = {}

# Debug log (opt-in only with bounded size and private permissions)
if os.environ.get("DEBUG_ANTIGRAVITY_HOOK") == "1":
    try:
        log_dir = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
        log_path = os.path.join(log_dir, "antigravity_hook_debug.log")
        flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        fd = os.open(log_path, flags, 0o600)
        with open(fd, "a", encoding="utf-8") as f:
            f.write(f"[{os.getpid()}] event={data.get('hook_event_name') or data.get('event')}\n")
    except Exception:
        pass

# 1. Fast-path: Ignore background, subagent, and non-actionable events
if (
    os.environ.get("AGENT2AGENTS_INITIALIZING") == "1"
    or os.environ.get("A2A_SILENT") == "1"
    or data.get("notification_type") in ["idle_prompt", "agent_needs_input", "agent_completed"]
    or data.get("hook_event_name") in ["idle_prompt", "agent_needs_input", "SubagentStop"]
    or data.get("event") in ["idle_prompt", "agent_needs_input", "SubagentStop"]
):
    print('{"decision": "allow"}' if "toolCall" in data else "{}")
    sys.exit(0)

# 2. Extract metadata
conversation_id = str(data.get("conversationId") or data.get("session_id") or data.get("sessionId") or "")
workspace_paths = data.get("workspacePaths") or []
project_hint = os.path.basename(workspace_paths[0]) if workspace_paths else os.path.basename(os.getcwd())

tool_call = data.get("toolCall") or {}
tool_name = tool_call.get("name") or data.get("tool_name") or ""
tool_args = tool_call.get("args") or data.get("tool_input") or {}

event_name = data.get("hook_event_name") or data.get("event") or ""

def resolve_env():
    env = os.environ.copy()
    if IS_WINDOWS:
        return env

    if not env.get("DISPLAY"):
        for disp in [":1", ":0"]:
            if os.path.exists(f"/tmp/.X11-unix/X{disp.lstrip(':')}"):
                env["DISPLAY"] = disp
                break
        else:
            env["DISPLAY"] = ":1"

    uid = os.getuid()
    if not env.get("XDG_RUNTIME_DIR"):
        env["XDG_RUNTIME_DIR"] = f"/run/user/{uid}"

    if not env.get("XAUTHORITY"):
        for xauth_path in [
            f"/run/user/{uid}/gdm/Xauthority",
            os.path.expanduser("~/.Xauthority"),
            f"/run/user/{uid}/.Xauthority",
        ]:
            if os.path.exists(xauth_path):
                env["XAUTHORITY"] = xauth_path
                break
    return env


def get_active_window_id(env=None):
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
    try:
        return subprocess.run(["xdotool", "getactivewindow"], capture_output=True, text=True, timeout=1, env=env).stdout.strip()
    except Exception:
        return ""


# 3. PreInvocation - early session capture
if "invocationNum" in data or event_name == "PreInvocation":
    if conversation_id and os.path.exists(MULTI_NOTIFY):
        env = resolve_env()
        caller_win = get_active_window_id(env)
        cmd = [
            PYTHON3, MULTI_NOTIFY,
            "--capture-session",
            "--app-name=Antigravity",
            f"--session-id={conversation_id}",
            f"--window-id={caller_win}",
            f"--caller-pid={os.getppid()}",
            f"--project-hint={project_hint}",
        ]
        creationflags = 0x08000000 if IS_WINDOWS else 0
        try:
            subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           creationflags=creationflags, timeout=4, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass
    print("{}")
    sys.exit(0)

def conversation_database_candidates(payload):
    """Return bounded, cross-platform locations for Antigravity metadata."""
    candidates = []
    configured = os.environ.get("ANTIGRAVITY_CONVERSATIONS_DB")
    if configured:
        candidates.append(Path(os.path.expandvars(os.path.expanduser(configured))))

    home = Path(USER_HOME)
    candidates.extend([
        home / ".gemini" / "antigravity-cli" / "conversation_summaries.db",
        home / ".gemini" / "antigravity" / "conversation_summaries.db",
    ])

    transcript_path = payload.get("transcriptPath") or payload.get("transcript_path")
    if transcript_path:
        transcript = Path(os.path.expandvars(os.path.expanduser(str(transcript_path))))
        for parent in list(transcript.parents)[:8]:
            candidates.append(parent / "conversation_summaries.db")

    unique = []
    seen = set()
    for candidate in candidates:
        key = os.path.normcase(os.path.abspath(str(candidate)))
        if key not in seen:
            seen.add(key)
            unique.append(candidate)
    return unique


def explicit_conversation_scope(payload):
    """Return True for root, False for subagent, or None when unspecified."""
    subagent_marker = payload.get("isSubagent", payload.get("is_subagent"))
    if subagent_marker is True or str(subagent_marker).lower() == "true":
        return False

    parent_keys = ("parentConversationId", "parent_conversation_id")
    depth_keys = ("nestingDepth", "nesting_depth")
    parent_present = any(key in payload for key in parent_keys)
    depth_present = any(key in payload for key in depth_keys)
    parent_id = next((payload.get(key) for key in parent_keys if key in payload), None)
    depth_value = next((payload.get(key) for key in depth_keys if key in payload), None)

    if str(parent_id or "").strip():
        return False
    if depth_present:
        try:
            if int(depth_value or 0) != 0:
                return False
        except (TypeError, ValueError):
            return None

    if subagent_marker is False or str(subagent_marker).lower() == "false":
        return True
    if parent_present and depth_present:
        return True
    return None


def is_root_antigravity_conversation(payload):
    """Fail closed unless the payload or local metadata proves this is a root."""
    explicit_scope = explicit_conversation_scope(payload)
    if explicit_scope is False:
        return False

    conversation_id = str(
        payload.get("conversationId")
        or payload.get("session_id")
        or payload.get("sessionId")
        or ""
    ).strip()
    if not conversation_id:
        return False

    for database_path in conversation_database_candidates(payload):
        if not database_path.is_file():
            continue
        connection = None
        try:
            database_uri = database_path.resolve().as_uri() + "?mode=ro"
            connection = sqlite3.connect(database_uri, uri=True, timeout=0.2)
            row = connection.execute(
                "SELECT parent_conversation_id, nesting_depth "
                "FROM conversation_summaries WHERE conversation_id = ? LIMIT 1",
                (conversation_id,),
            ).fetchone()
        except (OSError, RuntimeError, ValueError, sqlite3.Error):
            continue
        finally:
            if connection is not None:
                try:
                    connection.close()
                except sqlite3.Error:
                    pass

        if row is None:
            continue
        parent_id, depth_value = row
        try:
            nesting_depth = int(depth_value or 0)
        except (TypeError, ValueError):
            return False
        database_scope = not str(parent_id or "").strip() and nesting_depth == 0
        return database_scope

    return explicit_scope is True


def is_genuine_antigravity_completion(payload):
    if payload.get("fullyIdle") is not True:
        return False

    if payload.get("error"):
        return False

    term_reason = str(payload.get("terminationReason") or "").upper()
    if term_reason == "ERROR":
        return False

    event_name = payload.get("hook_event_name") or payload.get("event") or ""
    if event_name != "Stop":
        return False

    if not is_root_antigravity_conversation(payload):
        return False

    transcript_path = payload.get("transcriptPath")
    if transcript_path:
        candidate_paths = [
            transcript_path.replace("transcript_full.jsonl", "transcript.jsonl"),
            transcript_path,
        ]
        for path in candidate_paths:
            if os.path.exists(path):
                try:
                    with open(path, "rb") as f:
                        f.seek(0, os.SEEK_END)
                        size = f.tell()
                        f.seek(max(0, size - 65536), os.SEEK_SET)
                        chunk = f.read().decode("utf-8", errors="ignore")

                    lines = [l.strip() for l in chunk.splitlines() if l.strip()]
                    running_tasks = set()
                    completed_tasks = set()
                    steps = []

                    for line in lines:
                        try:
                            step = json.loads(line)
                            steps.append(step)

                            if step.get("status") == "RUNNING":
                                content = step.get("content", "")
                                if "task id:" in content:
                                    tid = content.split("task id:")[1].split()[0].strip()
                                    running_tasks.add(tid)

                            if step.get("source") == "SYSTEM" and step.get("type") == "SYSTEM_MESSAGE":
                                content = step.get("content", "")
                                if "Task id \"" in content and "finished with result" in content:
                                    tid = content.split("Task id \"")[1].split("\"")[0].strip()
                                    completed_tasks.add(tid)
                        except Exception:
                            continue

                    active_tasks = running_tasks - completed_tasks
                    if len(active_tasks) > 0:
                        return False

                    for step in reversed(steps):
                        if step.get("source") == "MODEL" and step.get("type") == "PLANNER_RESPONSE":
                            tool_calls = step.get("tool_calls") or []
                            if any("ask" in (tc.get("name") or "").lower() for tc in tool_calls):
                                return False
                            break
                except Exception:
                    pass

    return True


# 4. Check Question tool vs Completion vs Other tools
is_question = tool_name in ["ask_question", "AskUserQuestion", "ask_user"] or ("ask" in tool_name.lower())
is_completion = False if is_question else is_genuine_antigravity_completion(data)
event_type = "info"

if "toolCall" in data and not is_question:
    if os.path.exists(MULTI_NOTIFY):
        try:
            creationflags = 0x08000000 if IS_WINDOWS else 0
            subprocess.run(
                [PYTHON3, MULTI_NOTIFY, f"--session-id={conversation_id}", "--dismiss"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                timeout=1,
                creationflags=creationflags,
            )
        except Exception:
            pass
    print('{"decision": "allow"}')
    sys.exit(0)

if not is_question and not is_completion:
    print('{"decision": "allow"}' if "toolCall" in data else "{}")
    sys.exit(0)

# 5. Build Notification Details
title = "Antigravity"
message = "Antigravity đang chờ bạn."
urgency = "normal"
sound = "" if IS_WINDOWS else "/usr/share/sounds/freedesktop/stereo/complete.oga"
questions_json = ""
timeout = 0
is_pre_tool = False

if is_question:
    is_pre_tool = True
    event_type = "question"
    title = "Antigravity: Câu hỏi"
    urgency = "critical"
    if not IS_WINDOWS:
        sound = "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
    questions_json = json.dumps(tool_args) if tool_args else ""
    q_text = ""
    if isinstance(tool_args, dict):
        if "questions" in tool_args and isinstance(tool_args["questions"], list):
            q_text = " | ".join(q.get("question", "") for q in tool_args["questions"] if isinstance(q, dict) and q.get("question"))
        elif "question" in tool_args:
            q_text = str(tool_args["question"])
        elif "prompt" in tool_args:
            q_text = str(tool_args["prompt"])
    message = q_text or "Antigravity đang đặt câu hỏi cho bạn."

elif is_completion:
    event_type = "complete"
    title = "Antigravity: Hoàn thành"
    urgency = "normal"
    if not IS_WINDOWS:
        sound = "/usr/share/sounds/freedesktop/stereo/complete.oga"
    message = "Antigravity đã hoàn thành trả lời."

# Print response to agent loop immediately
print('{"decision": "allow"}' if is_pre_tool else "{}")
sys.stdout.flush()

# 6. Trigger popup asynchronously
if os.path.exists(MULTI_NOTIFY):
    env = resolve_env()
    cmd = [
        PYTHON3, MULTI_NOTIFY,
        "--app-name=Antigravity",
        f"--title={title}",
        f"--message={message}",
        f"--questions-json={questions_json}",
        f"--urgency={urgency}",
        f"--event-type={event_type}",
        f"--caller-pid={os.getppid()}",
        f"--project-hint={project_hint}",
        f"--session-id={conversation_id}",
        f"--timeout={timeout}",
    ]
    if sound:
        cmd.append(f"--sound={sound}")

    creationflags = 0x08000000 if IS_WINDOWS else 0
    start_session = False if IS_WINDOWS else True
    subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=start_session, creationflags=creationflags)

sys.exit(0)
