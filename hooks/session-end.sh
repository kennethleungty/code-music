#!/usr/bin/env bash

# SessionEnd hook for claude-music plugin
# Stops music playback when the session ends (including Ctrl+C)

# Never surface errors — just clean up and exit
trap 'exit 0' ERR
exec 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="$HOME/.claude-music"
STATE_FILE="$DATA_DIR/state.json"
POMODORO_PID_FILE="$DATA_DIR/pomodoro.pid"

# Kill pomodoro timer if active
if [ -f "$POMODORO_PID_FILE" ]; then
    kill "$(cat "$POMODORO_PID_FILE")" 2>/dev/null || true
    rm -f "$POMODORO_PID_FILE" "$DATA_DIR/pomodoro.json"
fi

# Kill the music player directly (faster than going through the controller)
if [ -f "$STATE_FILE" ]; then
    pid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('pid',''))" "$STATE_FILE" 2>/dev/null || true)
    if [ -n "$pid" ] && [ "$pid" != "null" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi
fi

# Also kill any mpv/ffplay that might have been started by the controller (belt and suspenders)
# Match broadly — any mpv/ffplay with --no-video or -nodisp (our launch flags)
pkill -f "mpv --no-video.*--really-quiet" 2>/dev/null || true
pkill -f "ffplay -nodisp" 2>/dev/null || true

# Kill the watchdog process too
WATCHDOG_PID_FILE="$DATA_DIR/watchdog.pid"
if [ -f "$WATCHDOG_PID_FILE" ]; then
    kill "$(cat "$WATCHDOG_PID_FILE")" 2>/dev/null || true
    rm -f "$WATCHDOG_PID_FILE"
fi

# Clean up state
if [ -f "$STATE_FILE" ]; then
    python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
d['status'] = 'stopped'
d['pid'] = ''
with open(sys.argv[1], 'w') as f: json.dump(d, f, indent=2)
" "$STATE_FILE" 2>/dev/null || true
fi

# SessionEnd hooks don't support hookSpecificOutput — output empty JSON
printf '{}\n'

exit 0
