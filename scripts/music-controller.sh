#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# claude-music controller — single entry point for all audio operations
# Usage: music-controller.sh <command> [args...]
# ============================================================================

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude-music}"
PREFS_FILE="$DATA_DIR/preferences.json"
STATE_FILE="$DATA_DIR/state.json"
PID_FILE="$DATA_DIR/player.pid"
MPV_SOCK="$DATA_DIR/mpv.sock"
STREAMS_FILE="$PLUGIN_ROOT/scripts/streams.json"
MUSIC_DIR="$PLUGIN_ROOT/music"

# ============================================================================
# JSON helpers — try jq, fallback to python3, fallback to sed
# ============================================================================

json_get() {
    local file="$1" key="$2"
    if command -v jq &>/dev/null; then
        jq -r ".$key // empty" "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
    else
        sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" 2>/dev/null | head -1
    fi
}

json_set() {
    local file="$1" key="$2" value="$3"
    if command -v jq &>/dev/null; then
        local tmp="${file}.tmp"
        jq ".$key = \"$value\"" "$file" > "$tmp" && mv "$tmp" "$file"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$file') as f: d=json.load(f)
d['$key']='$value'
with open('$file','w') as f: json.dump(d,f,indent=2)
"
    else
        sed -i "s/\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$key\": \"$value\"/" "$file"
    fi
}

# ============================================================================
# Utility functions
# ============================================================================

ensure_data_dir() {
    mkdir -p "$DATA_DIR"
}

init_prefs() {
    ensure_data_dir
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
}

detect_player() {
    # Check user preference first
    if [ -f "$PREFS_FILE" ]; then
        local pref
        pref=$(json_get "$PREFS_FILE" "player" 2>/dev/null || echo "auto")
        if [ "$pref" != "auto" ] && [ -n "$pref" ] && command -v "$pref" &>/dev/null; then
            echo "$pref"
            return 0
        fi
    fi

    # Auto-detect in priority order
    for player in mpv ffplay afplay play; do
        if command -v "$player" &>/dev/null; then
            echo "$player"
            return 0
        fi
    done

    # WSL/Windows: try Windows-side mpv.exe
    if command -v mpv.exe &>/dev/null; then
        echo "mpv.exe"
        return 0
    fi

    # WSL/Windows: PowerShell as last resort (limited but works for basic playback)
    if command -v powershell.exe &>/dev/null; then
        echo "powershell.exe"
        return 0
    fi

    echo "none"
    return 1
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

normalize_volume() {
    local vol="$1" player="$2"
    case "$player" in
        mpv|ffplay)
            echo "$vol"
            ;;
        afplay|play)
            # Convert 0-100 to 0.0-1.0
            if command -v awk &>/dev/null; then
                awk "BEGIN{printf \"%.2f\", $vol/100}"
            else
                echo "0.70"
            fi
            ;;
        *)
            echo "$vol"
            ;;
    esac
}

is_playing() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    else
        echo ""
    fi
}

kill_player() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        # Wait briefly for process to die
        sleep 0.2
        # Force kill if still alive
        kill -9 "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    rm -f "$MPV_SOCK"
}

save_state() {
    local status="$1" genre="$2" url="$3" player="$4" pid="$5"
    cat > "$STATE_FILE" <<EOF
{
  "status": "$status",
  "genre": "$genre",
  "url": "$url",
  "player": "$player",
  "pid": "$pid"
}
EOF
}

# ============================================================================
# Stream/track selection
# ============================================================================

get_stream_url() {
    local genre="${1:-lofi}"
    if [ ! -f "$STREAMS_FILE" ]; then
        echo ""
        return 1
    fi

    if command -v jq &>/dev/null; then
        # Pick a random URL from the genre array
        local count
        count=$(jq ".[\"$genre\"] | length" "$STREAMS_FILE" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            local idx=$((RANDOM % count))
            jq -r ".[\"$genre\"][$idx].url" "$STREAMS_FILE" 2>/dev/null
            return 0
        fi
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json,random
with open('$STREAMS_FILE') as f: d=json.load(f)
streams=d.get('$genre',[])
if streams: print(random.choice(streams)['url'])
else: exit(1)
" 2>/dev/null
        return $?
    fi

    echo ""
    return 1
}

get_stream_name() {
    local genre="${1:-lofi}" url="$2"
    if command -v jq &>/dev/null; then
        jq -r ".[\"$genre\"][] | select(.url==\"$url\") | .name" "$STREAMS_FILE" 2>/dev/null || echo "Unknown Station"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$STREAMS_FILE') as f: d=json.load(f)
for s in d.get('$genre',[]):
    if s['url']=='$url': print(s['name']); break
else: print('Unknown Station')
" 2>/dev/null
    else
        echo "Unknown Station"
    fi
}

get_fallback_file() {
    local genre="${1:-lofi}"
    local file="$MUSIC_DIR/${genre}-fallback.mp3"
    if [ -f "$file" ]; then
        echo "$file"
        return 0
    fi
    # Try any mp3 matching the genre
    local found
    found=$(find "$MUSIC_DIR" -name "${genre}*" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    # Default to any available mp3
    found=$(find "$MUSIC_DIR" -name "*.mp3" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    echo ""
    return 1
}

check_stream_reachable() {
    local url="$1"
    curl -sI --max-time 3 "$url" >/dev/null 2>&1
}

# ============================================================================
# Playback functions
# ============================================================================

do_play() {
    local genre="${1:-}"
    ensure_data_dir
    init_prefs

    # Resolve genre
    if [ -z "$genre" ]; then
        genre=$(json_get "$PREFS_FILE" "genre" 2>/dev/null || echo "lofi")
    fi
    [ -z "$genre" ] && genre="lofi"

    # Stop existing playback
    kill_player

    # Detect player
    local player
    player=$(detect_player)
    if [ "$player" = "none" ]; then
        echo '{"error": "No audio player found. Install mpv: brew install mpv (macOS) or apt install mpv (Linux)"}'
        return 1
    fi

    # Try stream first
    local url="" source="stream" stream_name=""
    url=$(get_stream_url "$genre" 2>/dev/null || echo "")

    if [ -n "$url" ] && check_stream_reachable "$url"; then
        source="stream"
        stream_name=$(get_stream_name "$genre" "$url")
    else
        # Fallback to local file
        url=$(get_fallback_file "$genre" 2>/dev/null || echo "")
        if [ -z "$url" ]; then
            echo "{\"error\": \"No stream available and no fallback MP3 found for genre: $genre\"}"
            return 1
        fi
        source="local"
        stream_name="$(basename "$url")"
    fi

    # Load volume
    local volume
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "70")
    [ -z "$volume" ] && volume="70"

    # Launch player in background
    local pid
    case "$player" in
        mpv)
            local vol_arg="$volume"
            if [ "$source" = "local" ]; then
                nohup mpv --no-video --really-quiet --volume="$vol_arg" --loop-file=inf --input-ipc-server="$MPV_SOCK" "$url" >/dev/null 2>&1 &
            else
                nohup mpv --no-video --really-quiet --volume="$vol_arg" --input-ipc-server="$MPV_SOCK" "$url" >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
        ffplay)
            local vol_arg="$volume"
            if [ "$source" = "local" ]; then
                nohup ffplay -nodisp -volume "$vol_arg" -loop 0 "$url" >/dev/null 2>&1 &
            else
                nohup ffplay -nodisp -volume "$vol_arg" "$url" >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
        afplay)
            local vol_float
            vol_float=$(normalize_volume "$volume" "afplay")
            if [ "$source" = "local" ]; then
                nohup bash -c "while true; do afplay -v $vol_float \"$url\"; done" >/dev/null 2>&1 &
            else
                # afplay can't stream — fallback to local only
                local fallback
                fallback=$(get_fallback_file "$genre" 2>/dev/null || echo "")
                if [ -n "$fallback" ]; then
                    url="$fallback"
                    source="local"
                    stream_name="$(basename "$url")"
                    nohup bash -c "while true; do afplay -v $vol_float \"$url\"; done" >/dev/null 2>&1 &
                else
                    echo '{"error": "afplay cannot stream URLs and no fallback MP3 found"}'
                    return 1
                fi
            fi
            pid=$!
            ;;
        play)
            local vol_float
            vol_float=$(normalize_volume "$volume" "play")
            if [ "$source" = "local" ]; then
                nohup play -v "$vol_float" "$url" repeat - >/dev/null 2>&1 &
            else
                nohup play -v "$vol_float" "$url" >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
        mpv.exe)
            # WSL: use Windows-side mpv
            local win_url="$url"
            if [ "$source" = "local" ]; then
                # Convert WSL path to Windows path
                win_url=$(wslpath -w "$url" 2>/dev/null || echo "$url")
                nohup mpv.exe --no-video --really-quiet --volume="$volume" --loop-file=inf "$win_url" >/dev/null 2>&1 &
            else
                nohup mpv.exe --no-video --really-quiet --volume="$volume" "$win_url" >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
        powershell.exe)
            # WSL/Windows: PowerShell MediaPlayer as last resort
            # Note: PowerShell MediaPlayer supports URLs and local files
            local win_url="$url"
            if [ "$source" = "local" ]; then
                win_url=$(wslpath -w "$url" 2>/dev/null || echo "$url")
            fi
            nohup powershell.exe -NoProfile -Command "
                Add-Type -AssemblyName PresentationCore
                \$p = New-Object System.Windows.Media.MediaPlayer
                \$p.Volume = $volume / 100
                \$p.Open([Uri]'$win_url')
                \$p.Play()
                while (\$true) { Start-Sleep -Seconds 60 }
            " >/dev/null 2>&1 &
            pid=$!
            ;;
    esac

    # Save PID and state
    echo "$pid" > "$PID_FILE"
    save_state "playing" "$genre" "$url" "$player" "$pid"

    # Update preferred genre
    json_set "$PREFS_FILE" "genre" "$genre"

    echo "{\"status\": \"playing\", \"genre\": \"$genre\", \"station\": \"$stream_name\", \"source\": \"$source\", \"player\": \"$player\"}"
}

do_stop() {
    if is_playing; then
        local genre
        genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "unknown")
        kill_player
        save_state "stopped" "$genre" "" "" ""
        echo "{\"status\": \"stopped\"}"
    else
        echo "{\"status\": \"already_stopped\"}"
    fi
}

do_pause() {
    if is_playing; then
        local pid
        pid=$(get_pid)
        local state
        state=$(ps -o state= -p "$pid" 2>/dev/null || echo "")
        if [ "$state" = "T" ]; then
            echo "{\"status\": \"already_paused\"}"
            return 0
        fi
        kill -STOP "$pid" 2>/dev/null
        if [ -f "$STATE_FILE" ]; then
            json_set "$STATE_FILE" "status" "paused"
        fi
        echo "{\"status\": \"paused\"}"
    else
        echo "{\"error\": \"Nothing is playing\"}"
        return 1
    fi
}

do_resume() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(get_pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill -CONT "$pid" 2>/dev/null
            if [ -f "$STATE_FILE" ]; then
                json_set "$STATE_FILE" "status" "playing"
            fi
            echo "{\"status\": \"resumed\"}"
            return 0
        fi
    fi
    echo "{\"error\": \"Nothing to resume\"}"
    return 1
}

do_next() {
    local genre
    genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "lofi")
    [ -z "$genre" ] && genre="lofi"

    # Stop current and play new stream (random selection will likely pick a different one)
    do_play "$genre"
}

do_status() {
    ensure_data_dir
    local status="stopped" genre="" url="" player="" station="" now_playing=""

    if [ -f "$STATE_FILE" ]; then
        status=$(json_get "$STATE_FILE" "status" 2>/dev/null || echo "stopped")
        genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "")
        url=$(json_get "$STATE_FILE" "url" 2>/dev/null || echo "")
        player=$(json_get "$STATE_FILE" "player" 2>/dev/null || echo "")
    fi

    # Verify PID is actually alive
    if [ "$status" = "playing" ] || [ "$status" = "paused" ]; then
        if ! is_playing; then
            status="stopped"
            save_state "stopped" "$genre" "" "" ""
        fi
    fi

    # Check actual pause state
    if [ "$status" = "playing" ] && is_playing; then
        local pid
        pid=$(get_pid)
        local ps_state
        ps_state=$(ps -o state= -p "$pid" 2>/dev/null || echo "")
        if [ "$ps_state" = "T" ]; then
            status="paused"
        fi
    fi

    # Get station name
    if [ -n "$url" ] && [ -n "$genre" ]; then
        station=$(get_stream_name "$genre" "$url" 2>/dev/null || echo "")
    fi

    # Try to get "now playing" metadata from mpv IPC socket
    if [ "$player" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
        now_playing=$(echo '{"command":["get_property","media-title"]}' | socat - "$MPV_SOCK" 2>/dev/null | \
            python3 -c "import json,sys; print(json.load(sys.stdin).get('data',''))" 2>/dev/null || echo "")
    fi

    local volume
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "70")

    cat <<EOF
{
  "status": "$status",
  "genre": "$genre",
  "station": "$station",
  "now_playing": "$now_playing",
  "volume": "$volume",
  "player": "$player",
  "url": "$url"
}
EOF
}

do_list_genres() {
    if command -v jq &>/dev/null; then
        jq -r 'keys[]' "$STREAMS_FILE" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json; [print(k) for k in json.load(open('$STREAMS_FILE')).keys()]" 2>/dev/null
    else
        echo "lofi"
        echo "jazz"
        echo "classical"
        echo "ambient"
    fi
}

do_load_prefs() {
    init_prefs
    local genre volume autoplay player
    genre=$(json_get "$PREFS_FILE" "genre" 2>/dev/null || echo "lofi")
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "70")
    autoplay=$(json_get "$PREFS_FILE" "autoplay" 2>/dev/null || echo "true")
    player=$(json_get "$PREFS_FILE" "player" 2>/dev/null || echo "auto")
    echo "genre=$genre volume=$volume autoplay=$autoplay player=$player"
}

do_save_pref() {
    local key="$1" value="$2"
    init_prefs
    json_set "$PREFS_FILE" "$key" "$value"
    echo "{\"saved\": \"$key=$value\"}"
}

# ============================================================================
# Main dispatch
# ============================================================================

case "${1:-help}" in
    play)           do_play "${2:-}" ;;
    stop)           do_stop ;;
    pause)          do_pause ;;
    resume)         do_resume ;;
    next)           do_next ;;
    status)         do_status ;;
    detect-player)  detect_player ;;
    load-prefs)     do_load_prefs ;;
    save-pref)      do_save_pref "${2:-}" "${3:-}" ;;
    list-genres)    do_list_genres ;;
    help|*)
        cat <<'USAGE'
claude-music controller

Commands:
  play [genre]        Start playback (lofi|jazz|classical|ambient)
  stop                Stop playback
  pause               Pause playback
  resume              Resume playback
  next                Skip to next stream/track
  status              Show current playback status
  detect-player       Show detected audio player
  load-prefs          Show current preferences
  save-pref KEY VAL   Update a preference
  list-genres         List available genres
USAGE
        ;;
esac
