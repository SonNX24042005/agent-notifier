#!/usr/bin/env bash

# Safe execution: errors in notification script must never crash or delay Claude Code
set +e

USER_HOME="${HOME:-/home/$USER}"
MULTI_NOTIFY="$USER_HOME/.local/bin/multi-desktop-notify.py"
JQ="/usr/bin/jq"
PYTHON3="$(command -v python3 || echo /usr/bin/python3)"

SOUND_WARNING="/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
SOUND_COMPLETE="/usr/share/sounds/freedesktop/stereo/complete.oga"

payload="$(cat)"

# 0. Empty payload check
if [ -z "$payload" ]; then
    exit 0
fi

# 1. Ignore background initialization from agent2agents immediately
if [ "${AGENT2AGENTS_INITIALIZING:-0}" = "1" ] || [ "${A2A_SILENT:-0}" = "1" ]; then
    exit 0
fi

if [[ "$payload" == *"Initializing imported session history"* ]]; then
    exit 0
fi

event_name="$(printf '%s' "$payload" | $JQ -r '.hook_event_name // .event // ""' 2>/dev/null)"
notif_type="$(printf '%s' "$payload" | $JQ -r '.notification_type // .type // .matcher // ""' 2>/dev/null)"
session_id="$(printf '%s' "$payload" | $JQ -r '.session_id // .sessionID // .session // ""' 2>/dev/null)"
cwd_path="$(printf '%s' "$payload" | $JQ -r '.cwd // ""' 2>/dev/null)"
project_hint=""
[ -n "$cwd_path" ] && project_hint="$(basename "$cwd_path" 2>/dev/null)"

# 2. Finish capture before the hook caller exits.
if [ "$event_name" = "SessionStart" ] || [ "$notif_type" = "SessionStart" ]; then
    if [ -x "$MULTI_NOTIFY" ]; then
        caller_window="$(timeout 1 xdotool getactivewindow 2>/dev/null || echo "")"
        caller_pid="$PPID"
        terminal_screen="${GNOME_TERMINAL_SCREEN:-}"
        timeout 4 "$PYTHON3" "$MULTI_NOTIFY" \
            --capture-session \
            --app-name="Claude Code" \
            --session-id="$session_id" \
            --window-id="$caller_window" \
            --caller-pid="$caller_pid" \
            --project-hint="$project_hint" \
            --terminal-screen="$terminal_screen" </dev/null >/dev/null 2>&1
    fi
    exit 0
fi

# 3. Fast-path: Ignore idle_prompt and non-actionable notifications
if [[ "$payload" == *"idle_prompt"* ]] || [[ "$payload" == *"agent_needs_input"* ]]; then
    exit 0
fi

# 4. Check for genuine events (Question, Permission, Completion)
is_question=0
is_permission=0
is_completion=0
event_type="info"

if [[ "$payload" == *"AskUserQuestion"* ]] || [[ "$payload" =~ [Aa]sk[Qq]uestion ]]; then
    is_question=1
    event_type="question"
elif [[ "$payload" == *"permission_prompt"* ]] || [[ "$payload" == *"PermissionRequest"* ]]; then
    is_permission=1
    event_type="permission"
elif [[ "$payload" == *"agent_completed"* ]] || [[ "$payload" == *"\"Stop\""* ]]; then
    is_completion=1
    event_type="complete"
fi

# If none of the genuine events matched, exit immediately (0ms)
if [ "$is_question" -eq 0 ] && [ "$is_permission" -eq 0 ] && [ "$is_completion" -eq 0 ]; then
    exit 0
fi
tool_name="$(printf '%s' "$payload" | $JQ -r '.tool_name // ""' 2>/dev/null)"

title="Claude Code"
message=""
urgency="normal"
sound=""
timeout="0"
should_notify=0
questions_json=""

if [ "$is_question" -eq 1 ]; then
    should_notify=1
    urgency="critical"
    sound="$SOUND_WARNING"
    title="Claude Code: Câu hỏi"
    timeout="0"
    questions_json="$(printf '%s' "$payload" | $JQ -c '.tool_input // {}' 2>/dev/null)"
    question="$(printf '%s' "$payload" | $JQ -r '
        if .tool_input.questions then
            .tool_input.questions | map(.question // .title // "") | join("\n")
        elif .tool_input.question then
            .tool_input.question
        elif .tool_input.prompt then
            .tool_input.prompt
        else
            .message // "Claude đang đặt câu hỏi cho bạn"
        end
    ' 2>/dev/null)"
    message="$question"

elif [ "$is_permission" -eq 1 ]; then
    should_notify=1
    urgency="critical"
    sound="$SOUND_WARNING"
    timeout="0"
    if [ -n "$tool_name" ]; then
        title="Claude Code: Cần cấp quyền ($tool_name)"
    else
        title="Claude Code: Cần cấp quyền"
    fi
    detail="$(printf '%s' "$payload" | $JQ -r '
        .tool_input.description //
        .tool_input.command //
        .message //
        "Claude cần bạn cấp quyền thực thi."
    ' 2>/dev/null)"
    message="$detail"

elif [ "$is_completion" -eq 1 ]; then
    should_notify=1
    urgency="normal"
    sound="$SOUND_COMPLETE"
    title="Claude Code: Hoàn thành"
    message="Claude đã hoàn thành trả lời."
    timeout="0"
fi

if [ "$should_notify" -eq 0 ]; then
    exit 0
fi

if [ -z "$message" ] || [ "$message" = "null" ]; then
    message="Claude Code đang chờ bạn."
fi

clean_message="$($PYTHON3 -c '
import sys
txt = " ".join(sys.argv[1].split())
if len(txt) > 400:
    txt = txt[:397] + "..."
print(txt)
' "$message" 2>/dev/null || printf '%s' "$message" | head -c 400)"

caller_pid="$PPID"
terminal_screen="${GNOME_TERMINAL_SCREEN:-}"
cwd_path="$(printf '%s' "$payload" | $JQ -r '.cwd // ""' 2>/dev/null)"
project_hint=""
[ -n "$cwd_path" ] && project_hint="$(basename "$cwd_path" 2>/dev/null)"

if [ -x "$MULTI_NOTIFY" ]; then
    setsid "$PYTHON3" "$MULTI_NOTIFY" \
        --app-name="Claude Code" \
        --title="$title" \
        --message="$clean_message" \
        --questions-json="$questions_json" \
        --urgency="$urgency" \
        --event-type="$event_type" \
        --sound="$sound" \
        --caller-pid="$caller_pid" \
        --project-hint="$project_hint" \
        --terminal-screen="$terminal_screen" \
        --session-id="$session_id" \
        --timeout="${timeout:-0}" </dev/null >/dev/null 2>&1 &
    disown
fi

exit 0
