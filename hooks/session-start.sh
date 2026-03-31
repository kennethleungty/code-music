#!/usr/bin/env bash

# SessionStart hook for claude-music plugin
# Deterministic platform/audio check — no LLM calls, no installs
# Injects platform state into session so Claude knows what to do

# Ensure the hook never surfaces an error to the user — all failures
# are handled inline with fallback defaults.
trap 'exit 0' ERR
exec 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROLLER="$PLUGIN_ROOT/scripts/music-controller.sh"
PLATFORM_DETECT="$PLUGIN_ROOT/scripts/platform-detect.sh"
SETUP_AUDIO="$PLUGIN_ROOT/scripts/setup-audio.sh"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude-music}"
PREFS_FILE="$DATA_DIR/preferences.json"

# ---- Set up status line (once) ----
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
    # Check if statusLine is already configured
    if ! grep -q '"statusLine"' "$CLAUDE_SETTINGS" 2>/dev/null; then
        # Add statusLine to existing settings
        STATUSLINE_CMD="$PLUGIN_ROOT/scripts/statusline.sh"
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
with open('$CLAUDE_SETTINGS') as f:
    settings = json.load(f)
settings['statusLine'] = {
    'type': 'command',
    'command': '$STATUSLINE_CMD',
    'padding': 2
}
with open('$CLAUDE_SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
        fi
    fi
elif [ -d "$HOME/.claude" ]; then
    # No settings.json yet — create one with just the statusLine
    STATUSLINE_CMD="$PLUGIN_ROOT/scripts/statusline.sh"
    cat > "$CLAUDE_SETTINGS" <<SEOF
{
  "statusLine": {
    "type": "command",
    "command": "$STATUSLINE_CMD",
    "padding": 2
  }
}
SEOF
fi

# ---- Initialize preferences ----
mkdir -p "$DATA_DIR"
if [ ! -f "$PREFS_FILE" ]; then
    cat > "$PREFS_FILE" <<'EOF'
{
  "genre": "ambient",
  "volume": "30",
  "autoplay": "false",
  "player": "auto"
}
EOF
fi

# ---- Reset muted volume on new session ----
# If the user muted (volume=0) in a previous session, restore to 30
if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    prefs = json.load(f)
vol = str(prefs.get('volume', '30'))
if vol == '0':
    prefs['volume'] = '30'
    with open(sys.argv[1], 'w') as f:
        json.dump(prefs, f, indent=2)
        f.write('\n')
" "$PREFS_FILE" 2>/dev/null || true
fi

# ---- Deterministic platform & audio detection ----
PLATFORM_JSON=$("$PLATFORM_DETECT" 2>/dev/null || echo '{}')
AUDIO_JSON=$("$SETUP_AUDIO" check 2>/dev/null || echo '{"audio_working": false}')

# Extract fields via python3 (fallback to safe defaults)
if command -v python3 &>/dev/null; then
    read_json() { echo "$1" | python3 -c "import json,sys; print(json.load(sys.stdin).get(sys.argv[1],sys.argv[2]))" "$2" "$3" 2>/dev/null || echo "$3"; }
    PLATFORM_OS=$(read_json "$PLATFORM_JSON" os unknown)
    PLATFORM_WSL=$(read_json "$PLATFORM_JSON" is_wsl False)
    PLATFORM_PKG=$(read_json "$PLATFORM_JSON" pkg_manager "")
    PLATFORM_PLAYERS=$(read_json "$PLATFORM_JSON" available_players "")
    PLATFORM_AUDIO_BACKEND=$(read_json "$PLATFORM_JSON" audio_backend none)
    AUDIO_WORKING=$(read_json "$AUDIO_JSON" audio_working False)
    AUDIO_METHOD=$(read_json "$AUDIO_JSON" method none)
else
    PLATFORM_OS="unknown"; PLATFORM_WSL="False"; PLATFORM_PKG=""
    PLATFORM_PLAYERS=""; PLATFORM_AUDIO_BACKEND="none"
    AUDIO_WORKING="False"; AUDIO_METHOD="none"
fi

# Check for a usable player via controller
PLAYER=$("$CONTROLLER" detect-player 2>/dev/null || echo "none")

# ---- Determine what's missing ----
MISSING=""
INSTALL_HINT=""

# Missing player?
if [ "$PLAYER" = "none" ]; then
    MISSING="player"
    HAS_SUDO=false
    if sudo -n true 2>/dev/null; then
        HAS_SUDO=true
    fi

    # Prefer no-sudo methods, then fall back to sudo if available
    if command -v brew &>/dev/null; then
        INSTALL_HINT="brew install mpv"
    elif command -v conda &>/dev/null; then
        INSTALL_HINT="conda install -c conda-forge mpv"
    elif command -v nix-env &>/dev/null; then
        INSTALL_HINT="nix-env -iA nixpkgs.mpv"
    elif [ "$HAS_SUDO" = true ]; then
        case "$PLATFORM_PKG" in
            apt)    INSTALL_HINT="sudo apt update && sudo apt install -y mpv" ;;
            dnf)    INSTALL_HINT="sudo dnf install -y mpv" ;;
            pacman) INSTALL_HINT="sudo pacman -S --noconfirm mpv" ;;
            apk)    INSTALL_HINT="sudo apk add mpv" ;;
            zypper) INSTALL_HINT="sudo zypper install -y mpv" ;;
            snap)   INSTALL_HINT="sudo snap install mpv" ;;
            *)      INSTALL_HINT="sudo apt update && sudo apt install -y mpv" ;;
        esac
    elif command -v snap &>/dev/null; then
        INSTALL_HINT="sudo snap install mpv (requires sudo — ask an admin if needed)"
    else
        case "$PLATFORM_PKG" in
            winget) INSTALL_HINT="winget install mpv" ;;
            scoop)  INSTALL_HINT="scoop install mpv" ;;
            choco)  INSTALL_HINT="choco install mpv" ;;
            *)      INSTALL_HINT="Install mpv from https://mpv.io/installation/ (or ask an admin to run: sudo apt install -y mpv)" ;;
        esac
    fi
fi

# Missing audio backend? (especially relevant on WSL)
if [ "$AUDIO_WORKING" = "False" ]; then
    if [ -n "$MISSING" ]; then
        MISSING="$MISSING,audio"
    else
        MISSING="audio"
    fi
fi

# ---- Load preferences & attempt autoplay ----
PREFS=$("$CONTROLLER" load-prefs 2>/dev/null || echo "genre=ambient volume=30 autoplay=false player=auto")
AUTOPLAY=$(echo "$PREFS" | grep -o 'autoplay=[^ ]*' | cut -d= -f2)
GENRE=$(echo "$PREFS" | grep -o 'genre=[^ ]*' | cut -d= -f2)

MUSIC_STATUS="no_player"
STATION=""
if [ "$PLAYER" != "none" ]; then
    if [ "$AUTOPLAY" = "true" ]; then
        PLAY_RESULT=$("$CONTROLLER" play "$GENRE" 2>/dev/null || echo '{"status":"error"}')
        MUSIC_STATUS="playing"
        if command -v python3 &>/dev/null; then
            STATION=$(read_json "$PLAY_RESULT" station "")
        fi
    else
        MUSIC_STATUS="ready"
    fi
fi

# ---- Build context message ----
CONTEXT="Background music plugin (claude-music) is active."
CONTEXT="$CONTEXT Environment: os=$PLATFORM_OS wsl=$PLATFORM_WSL pkg=$PLATFORM_PKG audio=$AUDIO_METHOD($AUDIO_WORKING) players=[$PLATFORM_PLAYERS]."

if [ -z "$MISSING" ]; then
    # Everything is good
    if [ "$MUSIC_STATUS" = "playing" ]; then
        CONTEXT="$CONTEXT Music is now playing: $GENRE"
        [ -n "$STATION" ] && CONTEXT="$CONTEXT ($STATION)"
        CONTEXT="$CONTEXT."
    elif [ "$MUSIC_STATUS" = "ready" ]; then
        CONTEXT="$CONTEXT Ready to play. Use /play to start."
    fi
else
    # Something is missing — give Claude the info to relay to the user quickly
    CONTEXT="$CONTEXT SETUP NEEDED (missing: $MISSING)."
    CONTEXT="$CONTEXT TONE: Present this warmly — music is almost ready to go, we just need a quick setup step first."
    if [[ "$MISSING" == *"player"* ]]; then
        CONTEXT="$CONTEXT No audio player (mpv or ffplay) is installed. Install command: $INSTALL_HINT"
        if [ "$HAS_SUDO" = true ]; then
            CONTEXT="$CONTEXT User has sudo — if they ask to play music, just run the install command directly and then start playback. No soundcheck agent needed."
        else
            CONTEXT="$CONTEXT User does NOT have sudo — if they ask to play music, automatically download a static ffplay binary to ~/.local/bin (no root needed) and start playback. No soundcheck agent, no asking — just do it."
        fi
    fi
    if [[ "$MISSING" == *"audio"* ]] && [ "$PLATFORM_WSL" = "True" ]; then
        CONTEXT="$CONTEXT WSL2 audio output is not set up yet — dispatch the soundcheck agent for WSL audio configuration help."
    fi
fi

CONTEXT="$CONTEXT Commands: /play, /stop, /next, /prev, /pause, /mute, /status, /list, /vibe, /dj, /mood, /focus, /pomodoro, /volume, /stats, /prefs, /reset, /sources, /feedback, /help"

# ---- Output JSON for Claude Code ----
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
printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$CONTEXT_ESCAPED"

exit 0
