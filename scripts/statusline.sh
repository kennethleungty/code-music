#!/bin/bash
# Claude Code status line script for claude-music
# Reads session JSON from stdin, appends now-playing info
# Output: ♪ lofi · SomaFM Groove Salad · "Track Name" | [Model] 42% context

input=$(cat)

# ---- JSON helper: jq with python3 fallback ----
json_val() {
    local json="$1" key="$2" default="$3"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".$key // empty" 2>/dev/null || echo "$default"
    elif command -v python3 &>/dev/null; then
        echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1],sys.argv[2]))" "$key" "$default" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

json_file_val() {
    local file="$1" key="$2" default="$3"
    if command -v jq &>/dev/null; then
        jq -r ".$key // empty" "$file" 2>/dev/null || echo "$default"
    elif command -v python3 &>/dev/null; then
        python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],sys.argv[3]))" "$file" "$key" "$default" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Parse session data for model and context
MODEL=$(json_val "$input" "model.display_name" "Claude")
# model.display_name is nested — need special handling
if command -v jq &>/dev/null; then
    MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null || echo "Claude")
elif command -v python3 &>/dev/null; then
    MODEL=$(echo "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('model',{}).get(sys.argv[1],sys.argv[2]))" "display_name" "Claude" 2>/dev/null || echo "Claude")
fi
PCT=$(json_val "$input" "context_window.used_percentage" "0")
if command -v jq &>/dev/null; then
    PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
elif command -v python3 &>/dev/null; then
    PCT=$(echo "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(int(d.get('context_window',{}).get(sys.argv[1],0)))" "used_percentage" 2>/dev/null || echo "0")
fi
[ -z "$PCT" ] && PCT="0"

# Determine data directory
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude-music}"
STATE_FILE="$DATA_DIR/state.json"
PID_FILE="$DATA_DIR/player.pid"

# Build music portion
MUSIC=""
if [ -f "$STATE_FILE" ] && [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        STATUS=$(json_file_val "$STATE_FILE" "status" "stopped")
        GENRE=$(json_file_val "$STATE_FILE" "genre" "")
        PLAYER=$(json_file_val "$STATE_FILE" "player" "")
        URL=$(json_file_val "$STATE_FILE" "url" "")

        # Get station name from sources.yml
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
        STATION=""
        if [ -n "$PLUGIN_ROOT" ] && [ -n "$URL" ] && [ -n "$GENRE" ] && command -v python3 &>/dev/null; then
            SOURCES="$PLUGIN_ROOT/config/sources.yml"
            if [ -f "$SOURCES" ]; then
                STATION=$(python3 -c "
import sys
sources_file, genre, url = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    import yaml
    with open(sources_file) as f: data = yaml.safe_load(f)
except ImportError:
    data = {}
    current_genre = None
    current_item = {}
    with open(sources_file) as f:
        for line in f:
            line = line.rstrip('\n')
            stripped = line.strip()
            if not stripped or stripped.startswith('#'): continue
            indent = len(line) - len(line.lstrip())
            if indent == 0 and stripped.endswith(':'):
                if current_item and current_genre: data[current_genre].append(current_item)
                current_genre = stripped[:-1]; data[current_genre] = []; current_item = {}
            elif indent == 2 and stripped.startswith('- name:'):
                if current_item and current_genre: data[current_genre].append(current_item)
                current_item = {'name': stripped.split(':', 1)[1].strip()}
            elif indent == 4 and stripped.startswith('url:'):
                current_item['url'] = stripped.split(': ', 1)[1].strip()
    if current_item and current_genre: data[current_genre].append(current_item)
import re
# Extract video ID from YouTube URLs (both short and resolved manifest URLs)
def yt_id(u):
    m = re.search(r'(?:v=|/vi?/)([a-zA-Z0-9_-]{11})', u or '')
    return m.group(1) if m else None
play_id = yt_id(url)
for s in data.get(genre, []):
    su = s.get('url', '')
    if su == url or (play_id and yt_id(su) == play_id):
        print(s['name']); break
" "$SOURCES" "$GENRE" "$URL" 2>/dev/null)
            fi
        fi

        # Try mpv IPC for track title
        NOW_PLAYING=""
        MPV_SOCK="$DATA_DIR/mpv.sock"
        if [ "$PLAYER" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
            if command -v jq &>/dev/null; then
                NOW_PLAYING=$(echo '{"command":["get_property","media-title"]}' | \
                    socat - "$MPV_SOCK" 2>/dev/null | \
                    jq -r '.data // ""' 2>/dev/null || echo "")
            elif command -v python3 &>/dev/null; then
                NOW_PLAYING=$(echo '{"command":["get_property","media-title"]}' | \
                    socat - "$MPV_SOCK" 2>/dev/null | \
                    python3 -c "import json,sys; print(json.load(sys.stdin).get('data',''))" 2>/dev/null || echo "")
            fi
            # Don't show if it's just the URL
            if echo "$NOW_PLAYING" | grep -q "^http" 2>/dev/null; then
                NOW_PLAYING=""
            fi
        fi

        # Check for active pomodoro timer
        POMO=""
        POMO_FILE="$DATA_DIR/pomodoro.json"
        if [ -f "$POMO_FILE" ]; then
            pomo_status=$(json_file_val "$POMO_FILE" "status" "none")
            if [ "$pomo_status" = "active" ]; then
                pomo_end=$(json_file_val "$POMO_FILE" "end_time" "0")
                now=$(date +%s)
                remaining_min=$(( (pomo_end - now + 59) / 60 ))
                if [ "$remaining_min" -gt 0 ]; then
                    POMO="\033[33m⏱ ${remaining_min}m\033[0m"
                fi
            fi
        fi

        # Build the display string
        if [ "$STATUS" = "playing" ]; then
            ICON="\033[32m♪\033[0m"  # green note
        else
            ICON=""
        fi

        # Check if muted
        PREFS_FILE="$DATA_DIR/preferences.json"
        VOL=""
        if [ -f "$PREFS_FILE" ]; then
            VOL=$(json_file_val "$PREFS_FILE" "volume" "")
        fi

        if [ -n "$ICON" ]; then
            MUSIC="$ICON \033[1mClaude Music\033[0m — Now playing: \033[36m${GENRE}\033[0m"
            [ -n "$STATION" ] && MUSIC="$MUSIC - $STATION"
            [ "$VOL" = "0" ] && MUSIC="$MUSIC \033[31m(muted)\033[0m"
            [ -n "$POMO" ] && MUSIC="$MUSIC · $POMO"
            [ -n "$NOW_PLAYING" ] && MUSIC="$MUSIC · \033[2m${NOW_PLAYING}\033[0m"
        fi
    fi
fi

# Compose final status line
if [ -n "$MUSIC" ]; then
    echo -e "[$MODEL] ${PCT}% ctx \033[2m|\033[0m $MUSIC"
elif [ -n "$CLAUDE_PLUGIN_ROOT" ]; then
    # Only show the idle prompt when the plugin is active in this session
    echo -e "[$MODEL] ${PCT}% ctx \033[2m| ♪ Claude Music — Enter /play to fill the silence with great music\033[0m"
fi
