#!/bin/bash
# Claude Code status line script for claude-music
# Reads session JSON from stdin, appends now-playing info
# Output: ♪ lofi · SomaFM Groove Salad · "Track Name" | [Model] 42% context

input=$(cat)

# Parse session data for model and context
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null || echo "Claude")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
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
        STATUS=$(jq -r '.status // "stopped"' "$STATE_FILE" 2>/dev/null || echo "stopped")
        GENRE=$(jq -r '.genre // ""' "$STATE_FILE" 2>/dev/null || echo "")
        PLAYER=$(jq -r '.player // ""' "$STATE_FILE" 2>/dev/null || echo "")

        # Check if paused
        PS_STATE=$(ps -o state= -p "$PID" 2>/dev/null || echo "")
        if [ "$PS_STATE" = "T" ]; then
            STATUS="paused"
        fi

        # Get station name from streams.json
        URL=$(jq -r '.url // ""' "$STATE_FILE" 2>/dev/null || echo "")
        PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
        STATION=""
        if [ -n "$PLUGIN_ROOT" ] && [ -n "$URL" ] && [ -n "$GENRE" ]; then
            STATION=$(jq -r ".[\"$GENRE\"][] | select(.url==\"$URL\") | .name" "$PLUGIN_ROOT/scripts/streams.json" 2>/dev/null || echo "")
        fi

        # Try mpv IPC for track title
        NOW_PLAYING=""
        MPV_SOCK="$DATA_DIR/mpv.sock"
        if [ "$PLAYER" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
            NOW_PLAYING=$(echo '{"command":["get_property","media-title"]}' | \
                socat - "$MPV_SOCK" 2>/dev/null | \
                jq -r '.data // ""' 2>/dev/null || echo "")
            # Don't show if it's just the URL
            if echo "$NOW_PLAYING" | grep -q "^http" 2>/dev/null; then
                NOW_PLAYING=""
            fi
        fi

        # Build the display string
        if [ "$STATUS" = "playing" ]; then
            ICON="\033[32m♪\033[0m"  # green note
        elif [ "$STATUS" = "paused" ]; then
            ICON="\033[33m⏸\033[0m"  # yellow pause
        else
            ICON=""
        fi

        if [ -n "$ICON" ]; then
            MUSIC="$ICON \033[36m${GENRE}\033[0m"
            [ -n "$STATION" ] && MUSIC="$MUSIC · $STATION"
            [ -n "$NOW_PLAYING" ] && MUSIC="$MUSIC · \033[2m${NOW_PLAYING}\033[0m"
        fi
    fi
fi

# Compose final status line
if [ -n "$MUSIC" ]; then
    echo -e "$MUSIC \033[2m|\033[0m [$MODEL] ${PCT}% ctx"
else
    echo "[$MODEL] ${PCT}% ctx"
fi
