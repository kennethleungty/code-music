#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook for claude-music plugin
# Initializes preferences, auto-plays music, injects context into session

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROLLER="$PLUGIN_ROOT/scripts/music-controller.sh"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude-music}"
PREFS_FILE="$DATA_DIR/preferences.json"

# Ensure data directory and preferences exist
mkdir -p "$DATA_DIR"
if [ ! -f "$PREFS_FILE" ]; then
    cat > "$PREFS_FILE" <<'EOF'
{
  "genre": "lofi",
  "volume": "70",
  "autoplay": "true",
  "player": "auto"
}
EOF
fi

# Detect available player
PLAYER=$("$CONTROLLER" detect-player 2>/dev/null || echo "none")

# Load preferences
PREFS=$("$CONTROLLER" load-prefs 2>/dev/null || echo "genre=lofi volume=70 autoplay=true player=auto")
AUTOPLAY=$(echo "$PREFS" | grep -o 'autoplay=[^ ]*' | cut -d= -f2)
GENRE=$(echo "$PREFS" | grep -o 'genre=[^ ]*' | cut -d= -f2)

# Auto-play if enabled and a player is available
MUSIC_STATUS="no_player"
STATION=""
if [ "$PLAYER" != "none" ]; then
    if [ "$AUTOPLAY" = "true" ]; then
        PLAY_RESULT=$("$CONTROLLER" play "$GENRE" 2>/dev/null || echo '{"status":"error"}')
        MUSIC_STATUS="playing"
        # Extract station name from result
        if command -v python3 &>/dev/null; then
            STATION=$(echo "$PLAY_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('station',''))" 2>/dev/null || echo "")
        fi
    else
        MUSIC_STATUS="ready"
    fi
fi

# Build context message
CONTEXT="Background music plugin (claude-music) is active."
if [ "$MUSIC_STATUS" = "playing" ]; then
    CONTEXT="$CONTEXT Music is now playing: $GENRE"
    [ -n "$STATION" ] && CONTEXT="$CONTEXT ($STATION)"
    CONTEXT="$CONTEXT."
elif [ "$MUSIC_STATUS" = "ready" ]; then
    CONTEXT="$CONTEXT Music is ready but autoplay is off. Use /music:play to start."
elif [ "$MUSIC_STATUS" = "no_player" ]; then
    CONTEXT="$CONTEXT No audio player found. You MUST invoke the claude-music:setup agent to automatically detect the platform and install mpv (or ffmpeg as fallback). Do this before anything else."
fi
CONTEXT="$CONTEXT Controls: /music:play, /music:stop, /music:pause, /music:resume, /music:next, /music:set-genre, /music:music-status"

# Escape for JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

CONTEXT_ESCAPED=$(escape_for_json "$CONTEXT")

# Output JSON for Claude Code context injection
printf '{\n  "hookSpecificOutput": {\n    "additionalContext": "%s"\n  }\n}\n' "$CONTEXT_ESCAPED"

exit 0
