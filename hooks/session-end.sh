#!/usr/bin/env bash

# SessionEnd hook for code-music plugin
# Stops music playback when the session ends (including Ctrl+C)

# Never surface errors — just clean up and exit
trap 'exit 0' ERR
exec 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="$HOME/.code-music"
STATE_FILE="$DATA_DIR/state.json"
POMODORO_PID_FILE="$DATA_DIR/pomodoro.pid"

# Kill pomodoro timer if active
if [ -f "$POMODORO_PID_FILE" ]; then
    kill "$(cat "$POMODORO_PID_FILE")" 2>/dev/null || true
    rm -f "$POMODORO_PID_FILE" "$DATA_DIR/pomodoro.json"
fi

# Kill the music player directly (faster than going through the controller)
if [ -f "$STATE_FILE" ]; then
    pid=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('pid',''))" 2>/dev/null || true)
    if [ -n "$pid" ] && [ "$pid" != "null" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi
fi

# Also kill any mpv/ffplay started by the controller (belt and suspenders)
pkill -f "mpv.*somafm\|mpv.*fallback\|ffplay.*somafm\|ffplay.*fallback" 2>/dev/null || true

# SessionEnd hooks don't support hookSpecificOutput — output empty JSON
printf '{}\n'

exit 0
