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
WATCHDOG_PID_FILE="$DATA_DIR/watchdog.pid"
MPV_SOCK="$DATA_DIR/mpv.sock"
STATIONS_FILE="$PLUGIN_ROOT/config/sources.yml"
ASSETS_DIR="$PLUGIN_ROOT/assets"
POMODORO_PID_FILE="$DATA_DIR/pomodoro.pid"
POMODORO_STATE_FILE="$DATA_DIR/pomodoro.json"

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
# YAML query helper — parses sources.yml via Python3
# ============================================================================

yaml_query() {
    local query="$1"
    if ! command -v python3 &>/dev/null; then
        echo ""
        return 1
    fi
    python3 -c "
import sys
try:
    import yaml
    with open('$STATIONS_FILE') as f:
        data = yaml.safe_load(f)
except ImportError:
    with open('$STATIONS_FILE') as f:
        text = f.read()
    # Minimal YAML subset parser for our flat structure
    # Format: genre: \n  - name: X \n    url: Y
    data = {}
    current_genre = None
    current_item = {}
    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        if indent == 0 and stripped.endswith(':'):
            if current_item and current_genre:
                data[current_genre].append(current_item)
                current_item = {}
            current_genre = stripped[:-1]
            data[current_genre] = []
        elif indent == 2 and stripped.startswith('- name:'):
            if current_item and current_genre:
                data[current_genre].append(current_item)
            current_item = {'name': stripped.split(':', 1)[1].strip()}
        elif indent == 4 and stripped.startswith('url:'):
            current_item['url'] = stripped.split(': ', 1)[1].strip()
    if current_item and current_genre:
        data[current_genre].append(current_item)
$query
" 2>/dev/null
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
  "autoplay": "false",
  "player": "auto",
  "favorite_stations": {}
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

find_session_tty() {
    # Walk up process tree to find an ancestor with a TTY (the user's terminal)
    local pid=$$
    local tty=""
    while [ "$pid" -gt 1 ] 2>/dev/null; do
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$tty" ] && [ "$tty" != "?" ]; then
            echo "$tty"
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

start_watchdog() {
    local player_pid="$1"
    local tty_dev
    tty_dev=$(find_session_tty 2>/dev/null || echo "")

    # If we can't find a TTY, nothing to monitor
    if [ -z "$tty_dev" ]; then
        return
    fi

    (
        while sleep 5; do
            # Player already dead — clean up and exit
            if ! kill -0 "$player_pid" 2>/dev/null; then
                rm -f "$PID_FILE" "$WATCHDOG_PID_FILE"
                exit 0
            fi
            # Terminal gone — kill the player
            if [ ! -e "/dev/$tty_dev" ]; then
                kill "$player_pid" 2>/dev/null
                sleep 0.2
                kill -9 "$player_pid" 2>/dev/null
                rm -f "$PID_FILE" "$WATCHDOG_PID_FILE" "$MPV_SOCK"
                exit 0
            fi
        done
    ) &>/dev/null &
    echo $! > "$WATCHDOG_PID_FILE"
    disown $! 2>/dev/null || true
}

kill_player() {
    # Kill watchdog first
    if [ -f "$WATCHDOG_PID_FILE" ]; then
        local wpid
        wpid=$(cat "$WATCHDOG_PID_FILE")
        kill "$wpid" 2>/dev/null || true
        rm -f "$WATCHDOG_PID_FILE"
    fi
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

    # Preserve session_start and station_count from existing state
    local session_start station_count
    session_start=$(json_get "$STATE_FILE" "session_start" 2>/dev/null || echo "")
    station_count=$(json_get "$STATE_FILE" "station_count" 2>/dev/null || echo "0")
    [ -z "$station_count" ] && station_count="0"

    # If starting fresh playback (not already playing), reset session tracking
    if [ "$status" = "playing" ] && [ -z "$session_start" ]; then
        session_start=$(date +%s)
        station_count="1"
    elif [ "$status" = "playing" ]; then
        station_count=$(( station_count + 1 ))
    fi

    # On stop, keep session_start for stats calculation
    cat > "$STATE_FILE" <<EOF
{
  "status": "$status",
  "genre": "$genre",
  "url": "$url",
  "player": "$player",
  "pid": "$pid",
  "session_start": "$session_start",
  "station_count": "$station_count"
}
EOF
}

# ============================================================================
# Stream/track selection
# ============================================================================

get_stream_url() {
    local genre="${1:-lofi}"
    local prefer_http="${2:-false}"
    local exclude_url="${3:-}"
    local favorite_url="${4:-}"
    if [ ! -f "$STATIONS_FILE" ]; then
        echo ""
        return 1
    fi
    yaml_query "
import random
streams = data.get('$genre', [])
prefer_http = '$prefer_http' == 'true'
exclude_url = '$exclude_url'
favorite_url = '$favorite_url'
if streams:
    if prefer_http:
        http_streams = [s for s in streams if s['url'].startswith('http://')]
        if http_streams:
            streams = http_streams
    if exclude_url and len(streams) > 1:
        streams = [s for s in streams if s['url'] != exclude_url]
    # Prefer the user's favorite station if available and not excluded
    if favorite_url and not exclude_url:
        fav = [s for s in streams if s['url'] == favorite_url]
        if fav:
            print(fav[0]['url'])
            sys.exit(0)
    print(random.choice(streams)['url'])
else:
    sys.exit(1)
"
    return $?
}

get_stream_name() {
    local genre="${1:-lofi}" url="$2"
    if [ ! -f "$STATIONS_FILE" ]; then
        echo "Unknown Station"
        return
    fi
    local name
    name=$(yaml_query "
for s in data.get('$genre', []):
    if s['url'] == '$url':
        print(s['name'])
        break
else:
    print('Unknown Station')
")
    echo "${name:-Unknown Station}"
}

get_fallback_file() {
    local genre="${1:-lofi}"
    local fallback_path="$ASSETS_DIR/${genre}_fallback.mp3"
    if [ -f "$fallback_path" ]; then
        echo "$fallback_path"
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

find_station_by_name() {
    local search="$1"
    [ ! -f "$STATIONS_FILE" ] && return 1
    yaml_query "
search = '''$search'''.lower()
for genre, streams in data.items():
    for s in streams:
        if search in s['name'].lower():
            print(genre + '|' + s['url'] + '|' + s['name'])
            sys.exit(0)
sys.exit(1)
"
    return $?
}

do_play() {
    local genre="${1:-}"
    local exclude_url="${2:-}"
    local force_url=""
    local force_station=""
    ensure_data_dir
    init_prefs

    # Check if the argument is a station name rather than a genre
    if [ -n "$genre" ] && [ ! -f "$STATIONS_FILE" ] || [ -n "$genre" ]; then
        local known_genres
        known_genres=$(do_list_genres 2>/dev/null)
        if ! echo "$known_genres" | grep -qx "$genre"; then
            # Not a known genre — try matching as a station name
            local match
            match=$(find_station_by_name "$genre" 2>/dev/null || echo "")
            if [ -n "$match" ]; then
                genre=$(echo "$match" | cut -d'|' -f1)
                force_url=$(echo "$match" | cut -d'|' -f2)
                force_station=$(echo "$match" | cut -d'|' -f3)
            fi
        fi
    fi

    # Resolve genre
    if [ -z "$genre" ]; then
        genre=$(json_get "$PREFS_FILE" "genre" 2>/dev/null || echo "lofi")
    fi
    [ -z "$genre" ] && genre="lofi"

    # Stop existing playback
    kill_player

    # Detect a usable player (mpv preferred, ffplay as fallback)
    local player
    player=$(detect_player)
    if [ "$player" = "none" ]; then
        local install_hint=""
        local has_sudo=false
        if sudo -n true 2>/dev/null; then
            has_sudo=true
        fi

        # Prefer no-sudo methods, then fall back to sudo
        if command -v brew &>/dev/null; then
            install_hint="brew install mpv"
        elif command -v conda &>/dev/null; then
            install_hint="conda install -c conda-forge mpv"
        elif command -v nix-env &>/dev/null; then
            install_hint="nix-env -iA nixpkgs.mpv"
        elif [ "$has_sudo" = true ]; then
            if command -v apt &>/dev/null; then
                install_hint="sudo apt update && sudo apt install -y mpv"
            elif command -v dnf &>/dev/null; then
                install_hint="sudo dnf install -y mpv"
            elif command -v pacman &>/dev/null; then
                install_hint="sudo pacman -S --noconfirm mpv"
            elif command -v snap &>/dev/null; then
                install_hint="sudo snap install mpv"
            fi
        fi

        # No-sudo static binary fallback: ffplay from ffmpeg static builds
        local nosudo_hint="curl -L https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz | tar xJ --strip-components=1 -C \$HOME/.local/bin/ --wildcards '*/ffplay'"

        if [ -z "$install_hint" ]; then
            install_hint="$nosudo_hint"
        fi

        echo "{\"error\": \"Music is all queued up, but no audio player (mpv or ffplay) is installed yet. Want me to set it up?\", \"install_command\": \"$install_hint\", \"nosudo_hint\": \"$nosudo_hint\", \"has_sudo\": $has_sudo}"
        return 1
    fi

    # Try stream first (PowerShell can't handle HTTPS streams, prefer HTTP)
    local url="" source="stream" stream_name=""
    local prefer_http="False"
    if [ "$player" = "powershell.exe" ]; then
        prefer_http="True"
    fi

    # If a specific station was matched by name, use it directly
    if [ -n "$force_url" ]; then
        url="$force_url"
        stream_name="$force_station"
    else
        # Get user's favorite station for this genre (used on /play, ignored on /next)
        local favorite_url=""
        if [ -z "$exclude_url" ]; then
            favorite_url=$(get_favorite_station "$genre")
        fi
        url=$(get_stream_url "$genre" "$prefer_http" "$exclude_url" "$favorite_url" 2>/dev/null || echo "")
    fi

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
            if [ "$source" = "local" ]; then
                nohup powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Volume = $volume / 100
                    \$p.Open([Uri]'$win_url')
                    \$p.Play()
                    Register-ObjectEvent \$p MediaEnded -Action {
                        \$p.Position = [TimeSpan]::Zero
                        \$p.Play()
                    } | Out-Null
                    while (\$true) { Start-Sleep -Seconds 60 }
                " >/dev/null 2>&1 &
            else
                nohup powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Volume = $volume / 100
                    \$p.Open([Uri]'$win_url')
                    \$p.Play()
                    while (\$true) { Start-Sleep -Seconds 60 }
                " >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
    esac

    # Save PID and start watchdog to kill player when terminal closes
    echo "$pid" > "$PID_FILE"
    start_watchdog "$pid"
    save_state "playing" "$genre" "$url" "$player" "$pid"

    # Record user's favorite genre and station
    json_set "$PREFS_FILE" "genre" "$genre"
    save_favorite_station "$genre" "$url"

    echo "{\"status\": \"playing\", \"genre\": \"$genre\", \"station\": \"$stream_name\", \"source\": \"$source\", \"player\": \"$player\"}"
}

do_stop() {
    # Cancel any active pomodoro timer
    kill_pomodoro
    if is_playing; then
        local genre session_start station_count duration_min
        genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "unknown")
        session_start=$(json_get "$STATE_FILE" "session_start" 2>/dev/null || echo "")
        station_count=$(json_get "$STATE_FILE" "station_count" 2>/dev/null || echo "1")

        # Calculate session duration
        duration_min=""
        if [ -n "$session_start" ] && [ "$session_start" != "0" ]; then
            local now elapsed
            now=$(date +%s)
            elapsed=$(( now - session_start ))
            duration_min=$(( elapsed / 60 ))
        fi

        kill_player
        # Clear session tracking on stop
        cat > "$STATE_FILE" <<EOF
{
  "status": "stopped",
  "genre": "$genre",
  "url": "",
  "player": "",
  "pid": "",
  "session_start": "",
  "station_count": "0"
}
EOF
        echo "{\"status\": \"stopped\", \"genre\": \"$genre\", \"duration_minutes\": \"${duration_min:-0}\", \"station_count\": \"${station_count:-1}\"}"
    else
        echo "{\"status\": \"already_stopped\"}"
    fi
}

do_next() {
    local genre current_url
    genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "lofi")
    [ -z "$genre" ] && genre="lofi"
    current_url=$(json_get "$STATE_FILE" "url" 2>/dev/null || echo "")

    # Play a different stream, excluding the current one
    do_play "$genre" "$current_url"
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
    if [ "$status" = "playing" ]; then
        if ! is_playing; then
            status="stopped"
            save_state "stopped" "$genre" "" "" ""
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
    if [ -f "$STATIONS_FILE" ]; then
        yaml_query "
for genre in data:
    print(genre)
"
    else
        echo "lofi"
        echo "jazz"
        echo "classical"
        echo "ambient"
    fi
}

do_load_prefs() {
    init_prefs
    # Output the full prefs file as JSON (includes favorite_stations)
    cat "$PREFS_FILE"
}

do_save_pref() {
    local key="$1" value="$2"
    init_prefs
    json_set "$PREFS_FILE" "$key" "$value"
    echo "{\"saved\": \"$key=$value\"}"
}

save_favorite_station() {
    local genre="$1" station_url="$2"
    [ -z "$genre" ] || [ -z "$station_url" ] && return
    init_prefs
    python3 -c "
import json, sys
try:
    with open('$PREFS_FILE') as f:
        prefs = json.load(f)
except:
    sys.exit(0)
favs = prefs.get('favorite_stations', {})
favs['$genre'] = '$station_url'
prefs['favorite_stations'] = favs
with open('$PREFS_FILE', 'w') as f:
    json.dump(prefs, f, indent=2)
" 2>/dev/null || true
}

get_favorite_station() {
    local genre="$1"
    python3 -c "
import json, sys
try:
    with open('$PREFS_FILE') as f:
        prefs = json.load(f)
    url = prefs.get('favorite_stations', {}).get('$genre', '')
    print(url)
except:
    print('')
" 2>/dev/null || echo ""
}

# ============================================================================
# Pomodoro timer
# ============================================================================

kill_pomodoro() {
    if [ -f "$POMODORO_PID_FILE" ]; then
        local pid
        pid=$(cat "$POMODORO_PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm -f "$POMODORO_PID_FILE"
    fi
    rm -f "$POMODORO_STATE_FILE"
}

fade_and_chime() {
    local player="$1"
    local chime_file="$ASSETS_DIR/chime.wav"

    # Fade volume down over 5 seconds (mpv only, others just stop)
    if [ "$player" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
        local current_vol
        current_vol=$(echo '{"command":["get_property","volume"]}' | socat - "$MPV_SOCK" 2>/dev/null | \
            python3 -c "import json,sys; print(int(json.load(sys.stdin).get('data',70)))" 2>/dev/null || echo "70")
        # Gradual fade: 5 steps over 5 seconds
        for step in 80 60 40 20 5; do
            local vol=$(( current_vol * step / 100 ))
            echo "{\"command\":[\"set_property\",\"volume\",$vol]}" | socat - "$MPV_SOCK" 2>/dev/null || true
            sleep 1
        done
    fi

    # Stop music
    kill_player

    # Play chime
    if [ -f "$chime_file" ]; then
        local chime_player
        chime_player=$(detect_player)
        case "$chime_player" in
            mpv)        mpv --no-video --really-quiet "$chime_file" 2>/dev/null ;;
            ffplay)     ffplay -nodisp -autoexit "$chime_file" 2>/dev/null ;;
            afplay)     afplay "$chime_file" 2>/dev/null ;;
            play)       play "$chime_file" 2>/dev/null ;;
            mpv.exe)
                local win_path
                win_path=$(wslpath -w "$chime_file" 2>/dev/null || echo "$chime_file")
                mpv.exe --no-video --really-quiet "$win_path" 2>/dev/null ;;
            powershell.exe)
                local win_path
                win_path=$(wslpath -w "$chime_file" 2>/dev/null || echo "$chime_file")
                powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Open([Uri]'$win_path')
                    \$p.Play()
                    Start-Sleep -Seconds 2
                " 2>/dev/null ;;
        esac
    fi
}

do_pomodoro() {
    local minutes="${1:-25}"
    local genre="${2:-}"
    ensure_data_dir

    # Validate minutes
    if ! [[ "$minutes" =~ ^[0-9]+$ ]] || [ "$minutes" -lt 1 ] || [ "$minutes" -gt 120 ]; then
        echo "{\"error\": \"Duration must be 1-120 minutes\"}"
        return 1
    fi

    # Kill any existing pomodoro timer
    kill_pomodoro

    # Start music (use provided genre or current preference)
    local play_result
    play_result=$(do_play "$genre")

    # Get the player for fade later
    local player
    player=$(json_get "$STATE_FILE" "player" 2>/dev/null || echo "")

    # Save pomodoro state
    local start_time end_time
    start_time=$(date +%s)
    end_time=$(( start_time + minutes * 60 ))
    cat > "$POMODORO_STATE_FILE" <<EOF
{
  "start_time": $start_time,
  "end_time": $end_time,
  "duration_minutes": $minutes,
  "status": "active"
}
EOF

    # Launch background timer
    (
        sleep $(( minutes * 60 ))
        # Timer expired — fade out and chime
        fade_and_chime "$player"
        # Update pomodoro state
        cat > "$POMODORO_STATE_FILE" <<INNER
{
  "start_time": $start_time,
  "end_time": $end_time,
  "duration_minutes": $minutes,
  "status": "completed"
}
INNER
        rm -f "$POMODORO_PID_FILE"
    ) &>/dev/null &
    local pomo_pid=$!
    echo "$pomo_pid" > "$POMODORO_PID_FILE"
    disown "$pomo_pid" 2>/dev/null || true

    # Extract station from play result
    local station genre_out
    station=$(echo "$play_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('station',''))" 2>/dev/null || echo "")
    genre_out=$(echo "$play_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('genre',''))" 2>/dev/null || echo "")

    echo "{\"status\": \"pomodoro_started\", \"duration_minutes\": $minutes, \"genre\": \"$genre_out\", \"station\": \"$station\"}"
}

do_pomodoro_status() {
    if [ ! -f "$POMODORO_STATE_FILE" ]; then
        echo "{\"status\": \"no_pomodoro\"}"
        return
    fi

    local pomo_status start_time end_time duration_minutes
    pomo_status=$(json_get "$POMODORO_STATE_FILE" "status" 2>/dev/null || echo "none")
    start_time=$(json_get "$POMODORO_STATE_FILE" "start_time" 2>/dev/null || echo "0")
    end_time=$(json_get "$POMODORO_STATE_FILE" "end_time" 2>/dev/null || echo "0")
    duration_minutes=$(json_get "$POMODORO_STATE_FILE" "duration_minutes" 2>/dev/null || echo "0")

    local now remaining_seconds remaining_minutes
    now=$(date +%s)
    remaining_seconds=$(( end_time - now ))
    if [ "$remaining_seconds" -lt 0 ]; then
        remaining_seconds=0
        pomo_status="completed"
    fi
    remaining_minutes=$(( remaining_seconds / 60 ))

    echo "{\"status\": \"$pomo_status\", \"duration_minutes\": $duration_minutes, \"remaining_minutes\": $remaining_minutes, \"remaining_seconds\": $remaining_seconds}"
}

do_pomodoro_stop() {
    if [ -f "$POMODORO_PID_FILE" ]; then
        kill_pomodoro
        kill_player
        save_state "stopped" "" "" "" ""
        echo "{\"status\": \"pomodoro_cancelled\"}"
    else
        echo "{\"status\": \"no_pomodoro\"}"
    fi
}

# ============================================================================
# Main dispatch
# ============================================================================

case "${1:-help}" in
    play)           do_play "${2:-}" ;;
    stop)           do_stop ;;
    next)           do_next ;;
    status)         do_status ;;
    detect-player)  detect_player ;;
    load-prefs)     do_load_prefs ;;
    save-pref)      do_save_pref "${2:-}" "${3:-}" ;;
    list-genres)        do_list_genres ;;
    pomodoro)           do_pomodoro "${2:-25}" "${3:-}" ;;
    pomodoro-status)    do_pomodoro_status ;;
    pomodoro-stop)      do_pomodoro_stop ;;
    help|*)
        cat <<'USAGE'
claude-music controller

Commands:
  play [genre]           Start playback (lofi|jazz|classical|ambient|edm)
  stop                   Stop playback
  next                   Skip to next stream in current genre
  status                 Show current playback status
  pomodoro [min] [genre] Start focus timer (default 25 min)
  pomodoro-status        Show timer remaining
  pomodoro-stop          Cancel focus timer and stop music
  detect-player          Show detected audio player
  load-prefs             Show current preferences
  save-pref KEY VAL      Update a preference
  list-genres            List available genres
USAGE
        ;;
esac
