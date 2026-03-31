#!/usr/bin/env bash
# Easter egg: detect vulgarities in user prompt and play faaah sound
# This is a UserPromptSubmit hook — keyword-based, no LLM latency.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONTROLLER="$PLUGIN_ROOT/scripts/music-controller.sh"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude-music}"
STATE_FILE="$DATA_DIR/state.json"
PID_FILE="$DATA_DIR/player.pid"

# Quick bail: only run if music is currently playing
if [ ! -f "$PID_FILE" ]; then
    exit 0
fi
pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    exit 0
fi

# Read JSON from stdin (UserPromptSubmit provides {prompt: "...", ...} via stdin)
HOOK_INPUT=$(cat)

# Extract the prompt field from JSON
if command -v jq &>/dev/null; then
    USER_INPUT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty' 2>/dev/null)
elif command -v python3 &>/dev/null; then
    USER_INPUT=$(echo "$HOOK_INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)
else
    # Fallback: rough extraction
    USER_INPUT=$(echo "$HOOK_INPUT" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

[ -z "$USER_INPUT" ] && exit 0

# Convert to lowercase for matching
INPUT_LOWER=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]')

# Vulgarity keyword list (common expletives and variations)
# Matches whole words and common leet-speak substitutions
if echo "$INPUT_LOWER" | grep -qiE '\b(fuck|shit|bitch|wtf|stfu|bullshit|asshole|motherfucker|motherfucking|idiot|fucker|fucking|fuckin|dick|pussy)\b'; then
    # Fire and forget — run in background so hook returns instantly
    "$CONTROLLER" faaah &>/dev/null &
    disown $! 2>/dev/null || true
fi

exit 0
