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
STATS_FILE="$DATA_DIR/stats.json"
LOCK_FILE="$DATA_DIR/controller.lock"
_TAKEOVER_PREV_GENRE=""

# ============================================================================
# JSON helpers — try jq, fallback to python3, fallback to sed
# ============================================================================

json_get() {
    local file="$1" key="$2"
    if command -v jq &>/dev/null; then
        jq -r ".$key // empty" "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get(sys.argv[2],''))" "$file" "$key" 2>/dev/null
    else
        sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" 2>/dev/null | head -1
    fi
}

json_set() {
    local file="$1" key="$2" value="$3"
    if command -v jq &>/dev/null; then
        local tmp="${file}.tmp"
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$file" > "$tmp" && mv "$tmp" "$file"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
with open(sys.argv[1]) as f: d=json.load(f)
d[sys.argv[2]]=sys.argv[3]
with open(sys.argv[1],'w') as f: json.dump(d,f,indent=2)
" "$file" "$key" "$value"
    else
        sed -i "s/\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$key\": \"$value\"/" "$file"
    fi
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# ============================================================================
# YAML query helper — parses sources.yml via Python3
# ============================================================================

yaml_query() {
    local query="$1"
    shift
    # Remaining args are key=value pairs passed as env vars to Python
    # This avoids interpolating user data into Python code (injection risk)
    if ! command -v python3 &>/dev/null; then
        echo ""
        return 1
    fi
    local env_args=()
    env_args+=("_YQ_STATIONS_FILE=$STATIONS_FILE")
    while [ $# -gt 0 ]; do
        env_args+=("$1")
        shift
    done
    env "${env_args[@]}" python3 -c "
import os, sys
_stations_file = os.environ['_YQ_STATIONS_FILE']
try:
    import yaml
    with open(_stations_file) as f:
        data = yaml.safe_load(f)
except ImportError:
    with open(_stations_file) as f:
        text = f.read()
    # Minimal YAML subset parser for our structure
    data = {}
    current_genre = None
    current_item = {}
    in_stations = False
    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        if indent == 0 and stripped.endswith(':'):
            if current_item and current_genre:
                data[current_genre].setdefault('stations', []).append(current_item)
                current_item = {}
            current_genre = stripped[:-1]
            data[current_genre] = {'stations': []}
            in_stations = False
        elif indent == 2 and stripped.startswith('stations:'):
            in_stations = True
        elif in_stations and indent == 4 and stripped.startswith('- name:'):
            if current_item and current_genre:
                data[current_genre]['stations'].append(current_item)
            current_item = {'name': stripped.split(':', 1)[1].strip()}
        elif in_stations and indent == 6 and stripped.startswith('url:'):
            current_item['url'] = stripped.split(': ', 1)[1].strip()
        elif in_stations and indent == 6 and stripped.startswith('description:'):
            current_item['description'] = stripped.split(': ', 1)[1].strip()
        elif in_stations and indent == 6 and stripped.startswith('tags:'):
            tag_str = stripped.split(':', 1)[1].strip().strip('[]')
            current_item['tags'] = [t.strip() for t in tag_str.split(',') if t.strip()]
    if current_item and current_genre:
        data[current_genre].setdefault('stations', []).append(current_item)
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
  "volume": "30",
  "autoplay": "false",
  "player": "auto",
  "favorite_stations": {}
}
EOF
    fi
}

detect_player() {
    # Return cached result if available (avoids repeated command -v calls)
    local cache_file="$DATA_DIR/detected_player.cache"
    if [ -f "$cache_file" ]; then
        local cached
        cached=$(cat "$cache_file")
        # Validate the cached player still exists
        if [ "$cached" != "none" ] && command -v "$cached" &>/dev/null; then
            # Check if a higher-priority player is now available
            local dominated=false
            for player in mpv ffplay afplay play; do
                if [ "$player" = "$cached" ]; then
                    break
                fi
                if command -v "$player" &>/dev/null; then
                    dominated=true
                    break
                fi
            done
            if [ "$dominated" = false ]; then
                echo "$cached"
                return 0
            fi
        fi
        # Cache stale or better player available, re-detect
        rm -f "$cache_file"
    fi

    local result="none"

    # Check user preference first
    if [ -f "$PREFS_FILE" ]; then
        local pref
        pref=$(json_get "$PREFS_FILE" "player" 2>/dev/null || echo "auto")
        if [ "$pref" != "auto" ] && [ -n "$pref" ] && command -v "$pref" &>/dev/null; then
            result="$pref"
        fi
    fi

    if [ "$result" = "none" ]; then
        # Auto-detect in priority order
        for player in mpv ffplay afplay play; do
            if command -v "$player" &>/dev/null; then
                result="$player"
                break
            fi
        done
    fi

    if [ "$result" = "none" ]; then
        # WSL/Windows: try Windows-side mpv.exe
        if command -v mpv.exe &>/dev/null; then
            result="mpv.exe"
        # WSL/Windows: PowerShell as last resort (limited but works for basic playback)
        elif command -v powershell.exe &>/dev/null; then
            result="powershell.exe"
        fi
    fi

    # Cache the result
    ensure_data_dir
    echo "$result" > "$cache_file"

    echo "$result"
    [ "$result" != "none" ] && return 0 || return 1
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

is_youtube_url() {
    local url="$1"
    case "$url" in
        *youtube.com/watch*|*youtu.be/*|*youtube.com/live/*) return 0 ;;
        *) return 1 ;;
    esac
}

install_ytdlp() {
    # Auto-install yt-dlp (needed for YouTube stream extraction via mpv)
    # Pinned version for reproducibility and supply-chain safety
    local YTDLP_VERSION="2026.3.17"
    # Try pip methods first (no root needed), then package managers
    if command -v pipx &>/dev/null; then
        pipx install "yt-dlp==$YTDLP_VERSION" &>/dev/null && return 0
    fi
    if command -v pip3 &>/dev/null; then
        pip3 install --user "yt-dlp==$YTDLP_VERSION" &>/dev/null && return 0
    fi
    if command -v pip &>/dev/null; then
        pip install --user "yt-dlp==$YTDLP_VERSION" &>/dev/null && return 0
    fi
    if command -v brew &>/dev/null; then
        brew install yt-dlp &>/dev/null && return 0
    fi
    if sudo -n true 2>/dev/null; then
        if command -v apt &>/dev/null; then
            sudo apt update -qq && sudo apt install -y -qq yt-dlp &>/dev/null && return 0
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y -q yt-dlp &>/dev/null && return 0
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm yt-dlp &>/dev/null && return 0
        fi
    fi
    # Final fallback: direct binary download (pinned version)
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    if curl -sL "https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VERSION/yt-dlp" -o "$bin_dir/yt-dlp" 2>/dev/null; then
        chmod +x "$bin_dir/yt-dlp"
        export PATH="$bin_dir:$PATH"
        return 0
    fi
    return 1
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
        if [ -n "$tty" ] && [ "$tty" != "?" ] && [ "$tty" != "??" ]; then
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
        while sleep 2; do
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
            # Note: we intentionally do NOT monitor the parent process ($PPID).
            # When Claude Code's Bash tool runs this script, $PPID is the
            # ephemeral bash process that exits as soon as the script returns,
            # which would kill the player after ~2 seconds. The TTY check above
            # already handles the "terminal closed" case.
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

kill_orphaned_players() {
    # Kill any audio player processes spawned by previous claude-music
    # sessions that aren't tracked by the current PID file (e.g. after a rename
    # or if the PID file was lost). This prevents overlapping audio.
    local pattern
    for pattern in 'music-controller\.sh play' 'somafm\.com' 'deepspaceone' 'youtube\.com/watch' 'yt-dlp.*youtube'; do
        local pids
        pids=$(pgrep -f "$pattern" 2>/dev/null || true)
        for p in $pids; do
            # Don't kill ourselves
            [ "$p" = "$$" ] && continue
            # Don't kill our parent chain
            [ "$p" = "$PPID" ] && continue
            kill "$p" 2>/dev/null || true
        done
    done
    # Also kill any orphaned PowerShell MediaPlayer instances playing streams
    local ps_pids
    ps_pids=$(pgrep -f 'powershell.*PresentationCore.*MediaPlayer' 2>/dev/null || true)
    for p in $ps_pids; do
        kill "$p" 2>/dev/null || true
    done
}

acquire_lock() {
    ensure_data_dir
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        # Lock held by another process — check if a player is actually running
        local prev_genre=""
        if is_playing; then
            # Another session is actively playing — full takeover
            if [ -f "$STATE_FILE" ]; then
                prev_genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "")
            fi
            kill_player
            kill_orphaned_players
            # Brief wait for lock release, then force-acquire
            sleep 0.3
            _TAKEOVER_PREV_GENRE="${prev_genre}"
        fi
        flock -w 2 9 2>/dev/null || true
    fi
}

acquire_lock_or_force() {
    # For stop: try to acquire lock, but if another session holds it,
    # wait briefly then proceed anyway — stop should always work.
    ensure_data_dir
    exec 9>"$LOCK_FILE"
    flock -w 2 9 2>/dev/null || true
}

acquire_lock_or_force_fast() {
    # For next/prev: try lock but never wait — just proceed immediately.
    ensure_data_dir
    exec 9>"$LOCK_FILE"
    flock -n 9 2>/dev/null || true
}

save_state() {
    local status="$1" genre="$2" url="$3" player="$4" pid="$5"

    # Preserve session_start and station_count from existing state
    local session_start station_count prev_url
    session_start=$(json_get "$STATE_FILE" "session_start" 2>/dev/null || echo "")
    station_count=$(json_get "$STATE_FILE" "station_count" 2>/dev/null || echo "0")
    [ -z "$station_count" ] && station_count="0"

    # Track previous URL for /prev support
    local old_url
    old_url=$(json_get "$STATE_FILE" "url" 2>/dev/null || echo "")
    if [ -n "$old_url" ] && [ "$old_url" != "$url" ]; then
        prev_url="$old_url"
    else
        prev_url=$(json_get "$STATE_FILE" "prev_url" 2>/dev/null || echo "")
    fi

    # If starting fresh playback, reset session tracking.
    # "Fresh" means: session_start is empty, OR the previous player is no longer alive
    # (e.g. it crashed or was killed). This prevents stale session_start values from
    # accumulating across broken sessions into an inflated duration.
    if [ "$status" = "playing" ]; then
        local prev_pid
        prev_pid=$(json_get "$STATE_FILE" "pid" 2>/dev/null || echo "")
        if [ -z "$session_start" ] || { [ -n "$prev_pid" ] && ! kill -0 "$prev_pid" 2>/dev/null; }; then
            session_start=$(date +%s)
            station_count="1"
        else
            station_count=$(( station_count + 1 ))
        fi
    fi

    # On stop, keep session_start for stats calculation
    cat > "$STATE_FILE" <<EOF
{
  "status": "$status",
  "genre": "$genre",
  "url": "$url",
  "player": "$player",
  "pid": "$pid",
  "prev_url": "$prev_url",
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
    if [ ! -f "$STATIONS_FILE" ]; then
        echo ""
        return 1
    fi
    yaml_query "
import random
genre_data = data.get(os.environ.get('_YQ_GENRE', ''), {})
streams = genre_data.get('stations', genre_data) if isinstance(genre_data, dict) else genre_data
if not isinstance(streams, list): streams = []
prefer_http = os.environ.get('_YQ_PREFER_HTTP', '') == 'true'
exclude_url = os.environ.get('_YQ_EXCLUDE_URL', '')
if streams:
    if prefer_http:
        http_streams = [s for s in streams if s['url'].startswith('http://')]
        if http_streams:
            streams = http_streams
    if exclude_url and len(streams) > 1:
        streams = [s for s in streams if s['url'] != exclude_url]
    print(random.choice(streams)['url'])
else:
    sys.exit(1)
" "_YQ_GENRE=$genre" "_YQ_PREFER_HTTP=$prefer_http" "_YQ_EXCLUDE_URL=$exclude_url"
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
genre_data = data.get(os.environ.get('_YQ_GENRE', ''), {})
streams = genre_data.get('stations', genre_data) if isinstance(genre_data, dict) else genre_data
if not isinstance(streams, list): streams = []
for s in streams:
    if s['url'] == os.environ.get('_YQ_URL', ''):
        print(s['name'])
        break
else:
    print('Unknown Station')
" "_YQ_GENRE=$genre" "_YQ_URL=$url")
    echo "${name:-Unknown Station}"
}

# Combined URL+name lookup in a single Python call (avoids double YAML parse)
get_stream_url_and_name() {
    local genre="${1:-lofi}"
    local prefer_http="${2:-false}"
    local exclude_url="${3:-}"
    if [ ! -f "$STATIONS_FILE" ]; then
        echo "|Unknown Station"
        return 1
    fi
    yaml_query "
import random
genre_data = data.get(os.environ.get('_YQ_GENRE', ''), {})
streams = genre_data.get('stations', genre_data) if isinstance(genre_data, dict) else genre_data
if not isinstance(streams, list): streams = []
prefer_http = os.environ.get('_YQ_PREFER_HTTP', '') == 'true'
exclude_url = os.environ.get('_YQ_EXCLUDE_URL', '')
if streams:
    if prefer_http:
        http_streams = [s for s in streams if s['url'].startswith('http://')]
        if http_streams:
            streams = http_streams
    if exclude_url and len(streams) > 1:
        streams = [s for s in streams if s['url'] != exclude_url]
    choice = random.choice(streams)
    print(choice['url'] + '|' + choice.get('name', 'Unknown Station'))
else:
    sys.exit(1)
" "_YQ_GENRE=$genre" "_YQ_PREFER_HTTP=$prefer_http" "_YQ_EXCLUDE_URL=$exclude_url"
    return $?
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
search = os.environ.get('_YQ_SEARCH', '').lower()
for genre, genre_data in data.items():
    streams = genre_data.get('stations', genre_data) if isinstance(genre_data, dict) else genre_data
    if not isinstance(streams, list): streams = []
    for s in streams:
        if search in s['name'].lower():
            print(genre + '|' + s['url'] + '|' + s['name'])
            sys.exit(0)
sys.exit(1)
" "_YQ_SEARCH=$search"
    return $?
}

do_play() {
    local genre="${1:-}"
    local exclude_url="${2:-}"
    local force_url="${3:-}"
    local force_station=""
    ensure_data_dir
    init_prefs

    # Genre aliases
    case "$genre" in
        edm) genre="electronic" ;;
    esac

    # Check if the argument is a station name rather than a genre
    if [ -n "$genre" ]; then
        # Fast genre check without spawning a subprocess
        local is_known_genre=false
        case "$genre" in
            lofi|jazz|classical|ambient|electronic|synthwave|lounge|indie) is_known_genre=true ;;
        esac
        if [ "$is_known_genre" = false ]; then
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

    # Resolve genre and track why it was chosen
    local genre_reason="requested"
    if [ -z "$genre" ]; then
        genre=$(json_get "$PREFS_FILE" "genre" 2>/dev/null || echo "")
        if [ -n "$genre" ]; then
            genre_reason="preference"
        else
            genre="lofi"
            genre_reason="default"
        fi
    fi
    [ -z "$genre" ] && genre="lofi"

    # Stop existing playback (tracked player only — orphan cleanup already
    # happens in acquire_lock on takeover, no need to repeat here)
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

        printf '{"error": "Music is all queued up, but no audio player (mpv or ffplay) is installed yet. Want me to set it up?", "install_command": "%s", "nosudo_hint": "%s", "has_sudo": %s}\n' "$(json_escape "$install_hint")" "$(json_escape "$nosudo_hint")" "$has_sudo"
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
        # Single YAML parse to get URL and station name
        local url_and_meta
        url_and_meta=$(get_stream_url_and_name "$genre" "$prefer_http" "$exclude_url" 2>/dev/null || echo "")
        if [ -n "$url_and_meta" ]; then
            url=$(echo "$url_and_meta" | cut -d'|' -f1)
            stream_name=$(echo "$url_and_meta" | cut -d'|' -f2)
        fi
    fi

    if [ -n "$url" ]; then
        source="stream"
        # YouTube URLs require yt-dlp — auto-install if missing
        if is_youtube_url "$url" && ! command -v yt-dlp &>/dev/null; then
            install_ytdlp
        fi
        # For non-mpv players, extract the direct audio URL via yt-dlp
        # (mpv handles yt-dlp internally, but ffplay/others need the raw stream URL)
        if is_youtube_url "$url" && [ "$player" != "mpv" ] && [ "$player" != "mpv.exe" ]; then
            if command -v yt-dlp &>/dev/null; then
                local direct_url
                direct_url=$(yt-dlp --no-warnings -f "bestaudio/worst" --get-url "$url" 2>/dev/null || echo "")
                if [ -n "$direct_url" ]; then
                    url="$direct_url"
                fi
            fi
        fi
    else
        # Fallback to local file
        url=$(get_fallback_file "$genre" 2>/dev/null || echo "")
        if [ -z "$url" ]; then
            printf '{"error": "No stream available and no fallback MP3 found for genre: %s"}\n' "$(json_escape "$genre")"
            return 1
        fi
        source="local"
        stream_name="$(basename "$url")"
    fi

    # Load volume
    local volume
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "30")
    [ -z "$volume" ] && volume="30"

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
                nohup bash -c 'while true; do afplay -v "$1" "$2"; done' _ "$vol_float" "$url" >/dev/null 2>&1 &
            else
                # afplay can't stream — fallback to local only
                local fallback
                fallback=$(get_fallback_file "$genre" 2>/dev/null || echo "")
                if [ -n "$fallback" ]; then
                    url="$fallback"
                    source="local"
                    stream_name="$(basename "$url")"
                    nohup bash -c 'while true; do afplay -v "$1" "$2"; done' _ "$vol_float" "$url" >/dev/null 2>&1 &
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
            # URL and volume are passed via environment variables to avoid
            # PowerShell injection from malicious URLs
            local win_url="$url"
            if [ "$source" = "local" ]; then
                win_url=$(wslpath -w "$url" 2>/dev/null || echo "$url")
            fi
            if [ "$source" = "local" ]; then
                nohup env _CM_URL="$win_url" _CM_VOL="$volume" powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Volume = [int]\$env:_CM_VOL / 100
                    \$p.Open([Uri]\$env:_CM_URL)
                    \$p.Play()
                    Register-ObjectEvent \$p MediaEnded -Action {
                        \$p.Position = [TimeSpan]::Zero
                        \$p.Play()
                    } | Out-Null
                    while (\$true) { Start-Sleep -Seconds 60 }
                " >/dev/null 2>&1 &
            else
                nohup env _CM_URL="$win_url" _CM_VOL="$volume" powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Volume = [int]\$env:_CM_VOL / 100
                    \$p.Open([Uri]\$env:_CM_URL)
                    \$p.Play()
                    while (\$true) { Start-Sleep -Seconds 60 }
                " >/dev/null 2>&1 &
            fi
            pid=$!
            ;;
    esac

    # Save PID, start watchdog, and return immediately — no blocking health check.
    echo "$pid" > "$PID_FILE"
    start_watchdog "$pid"
    save_state "playing" "$genre" "$url" "$player" "$pid"

    # Record user's favorite genre and station
    json_set "$PREFS_FILE" "genre" "$genre"
    save_favorite_station "$genre" "$url"

    local takeover_field=""
    if [ -n "$_TAKEOVER_PREV_GENRE" ]; then
        takeover_field="$(printf ', "takeover": true, "prev_genre": "%s"' "$(json_escape "$_TAKEOVER_PREV_GENRE")")"
    fi
    printf '{"status": "playing", "genre": "%s", "genre_reason": "%s", "station": "%s", "source": "%s", "player": "%s"%s}\n' \
        "$(json_escape "$genre")" "$(json_escape "$genre_reason")" "$(json_escape "$stream_name")" \
        "$(json_escape "$source")" "$(json_escape "$player")" "$takeover_field"

    # Background health check + auto-retry: returns immediately, checks
    # player health asynchronously to avoid blocking the caller.
    if [ "$source" = "stream" ]; then
        (
            # Quick check: catch immediate crashes (bad URL, player error)
            sleep 1
            if ! kill -0 "$pid" 2>/dev/null; then
                local retry_meta
                retry_meta=$(get_stream_url_and_name "$genre" "$prefer_http" "$url" 2>/dev/null || echo "")
                if [ -n "$retry_meta" ]; then
                    local retry_url retry_name
                    retry_url=$(echo "$retry_meta" | cut -d'|' -f1)
                    retry_name=$(echo "$retry_meta" | cut -d'|' -f2)
                    if is_youtube_url "$retry_url" && [ "$player" != "mpv" ] && [ "$player" != "mpv.exe" ]; then
                        if command -v yt-dlp &>/dev/null; then
                            local direct
                            direct=$(yt-dlp --no-warnings -f "bestaudio[ext=m4a]/bestaudio" --get-url "$retry_url" 2>/dev/null || echo "")
                            [ -n "$direct" ] && retry_url="$direct"
                        fi
                    fi
                    case "$player" in
                        mpv)    nohup mpv --no-video --really-quiet --volume="$volume" --input-ipc-server="$MPV_SOCK" "$retry_url" >/dev/null 2>&1 & ;;
                        ffplay) nohup ffplay -nodisp -volume "$volume" "$retry_url" >/dev/null 2>&1 & ;;
                        *)      nohup "$player" "$retry_url" >/dev/null 2>&1 & ;;
                    esac
                    pid=$!
                    echo "$pid" > "$PID_FILE"
                    save_state "playing" "$genre" "$retry_url" "$player" "$pid"
                fi
            fi

            # Deferred check: catch slower failures (e.g. stream drops after connect)
            local health_delay=3
            if is_youtube_url "$url" && { [ "$player" = "mpv" ] || [ "$player" = "mpv.exe" ]; }; then
                health_delay=8
            fi
            sleep "$health_delay"
            if ! kill -0 "$pid" 2>/dev/null; then
                local retry_meta
                retry_meta=$("$0" _get_stream_url_and_name "$genre" "$prefer_http" "$url" 2>/dev/null || \
                    get_stream_url_and_name "$genre" "$prefer_http" "$url" 2>/dev/null || echo "")
                if [ -n "$retry_meta" ]; then
                    local retry_url retry_name
                    retry_url=$(echo "$retry_meta" | cut -d'|' -f1)
                    retry_name=$(echo "$retry_meta" | cut -d'|' -f2)
                    if is_youtube_url "$retry_url" && [ "$player" != "mpv" ] && [ "$player" != "mpv.exe" ]; then
                        if command -v yt-dlp &>/dev/null; then
                            local direct
                            direct=$(yt-dlp --no-warnings -f "bestaudio[ext=m4a]/bestaudio" --get-url "$retry_url" 2>/dev/null || echo "")
                            [ -n "$direct" ] && retry_url="$direct"
                        fi
                    fi
                    case "$player" in
                        mpv)
                            nohup mpv --no-video --really-quiet --volume="$volume" --input-ipc-server="$MPV_SOCK" "$retry_url" >/dev/null 2>&1 &
                            ;;
                        ffplay)
                            nohup ffplay -nodisp -volume "$volume" "$retry_url" >/dev/null 2>&1 &
                            ;;
                        *)
                            nohup "$player" "$retry_url" >/dev/null 2>&1 &
                            ;;
                    esac
                    local new_pid=$!
                    echo "$new_pid" > "$PID_FILE"
                    save_state "playing" "$genre" "$retry_url" "$player" "$new_pid"
                fi
            fi
        ) &>/dev/null &
        disown $! 2>/dev/null || true
    fi
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

        # Update lifetime + daily stats
        update_stats "$genre" "${duration_min:-0}" "${station_count:-1}"

        # Read today's cumulative stats after update
        local today_stats=""
        if command -v python3 &>/dev/null && [ -f "$STATS_FILE" ]; then
            today_stats=$(python3 -c "
import json, datetime, sys
with open(sys.argv[1]) as f:
    stats = json.load(f)
today = datetime.date.today().isoformat()
d = stats.get('daily', {}).get(today, {})
print(json.dumps({
    'today_sessions': d.get('sessions', 0),
    'today_minutes': d.get('minutes', 0),
    'today_stations': d.get('stations', 0),
    'today_genres': d.get('genres', {})
}))
" "$STATS_FILE" 2>/dev/null || echo '{}')
        fi
        [ -z "$today_stats" ] && today_stats='{}'

        # Clear session tracking on stop
        # Preserve prev_url so /prev works after stop+play
        local prev_url
        prev_url=$(json_get "$STATE_FILE" "prev_url" 2>/dev/null || echo "")
        cat > "$STATE_FILE" <<EOF
{
  "status": "stopped",
  "genre": "$genre",
  "url": "",
  "player": "",
  "pid": "",
  "prev_url": "$prev_url",
  "session_start": "",
  "station_count": "0"
}
EOF
        # Merge session + today stats into response
        python3 -c "
import json, sys
session = {'status': 'stopped', 'genre': sys.argv[1], 'duration_minutes': sys.argv[2], 'station_count': sys.argv[3]}
today = json.loads(sys.argv[4])
session.update(today)
print(json.dumps(session))
" "$genre" "${duration_min:-0}" "${station_count:-1}" "$today_stats" 2>/dev/null || printf '{"status": "stopped", "genre": "%s", "duration_minutes": "%s", "station_count": "%s"}\n' \
            "$(json_escape "$genre")" "${duration_min:-0}" "${station_count:-1}"
    else
        echo "{\"status\": \"already_stopped\"}"
    fi
}

do_shuffle() {
    # Pick a completely random genre, then let do_play pick a random station within it
    local genres
    genres=$(do_list_genres 2>/dev/null)
    local genre
    genre=$(echo "$genres" | shuf -n 1)
    [ -z "$genre" ] && genre="lofi"
    do_play "$genre"
}

do_next() {
    local genre current_url
    genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "lofi")
    [ -z "$genre" ] && genre="lofi"
    current_url=$(json_get "$STATE_FILE" "url" 2>/dev/null || echo "")

    # Play a different stream, excluding the current one
    do_play "$genre" "$current_url"
}

do_prev() {
    local genre prev_url
    genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "lofi")
    [ -z "$genre" ] && genre="lofi"
    prev_url=$(json_get "$STATE_FILE" "prev_url" 2>/dev/null || echo "")

    if [ -z "$prev_url" ]; then
        cat <<EOF
{
  "status": "error",
  "message": "No previous station to go back to"
}
EOF
        return
    fi

    # Play the previous stream by passing it as the genre's forced URL
    do_play "$genre" "" "$prev_url"
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
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "30")

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
        echo "lofi"
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
    printf '{"saved": "%s=%s"}\n' "$(json_escape "$key")" "$(json_escape "$value")"
}

do_reset_prefs() {
    ensure_data_dir
    cat > "$PREFS_FILE" <<'EOF'
{
  "genre": "lofi",
  "volume": "30",
  "autoplay": "false",
  "player": "auto",
  "favorite_stations": {}
}
EOF
    echo "{\"status\": \"reset\", \"message\": \"Preferences cleared. Genre default is now ambient.\"}"
}

save_favorite_station() {
    local genre="$1" station_url="$2"
    [ -z "$genre" ] || [ -z "$station_url" ] && return
    init_prefs
    python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        prefs = json.load(f)
except:
    sys.exit(0)
favs = prefs.get('favorite_stations', {})
favs[sys.argv[2]] = sys.argv[3]
prefs['favorite_stations'] = favs
with open(sys.argv[1], 'w') as f:
    json.dump(prefs, f, indent=2)
" "$PREFS_FILE" "$genre" "$station_url" 2>/dev/null || true
}

get_favorite_station() {
    local genre="$1"
    python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        prefs = json.load(f)
    url = prefs.get('favorite_stations', {}).get(sys.argv[2], '')
    print(url)
except:
    print('')
" "$PREFS_FILE" "$genre" 2>/dev/null || echo ""
}

# ============================================================================
# Lifetime stats
# ============================================================================

init_stats() {
    ensure_data_dir
    if [ ! -f "$STATS_FILE" ]; then
        cat > "$STATS_FILE" <<'EOF'
{
  "total_sessions": 0,
  "total_minutes": 0,
  "total_stations": 0,
  "genres": {},
  "first_session": null,
  "last_session": null
}
EOF
    fi
}

update_stats() {
    local genre="$1" duration_min="$2" station_count="$3"
    init_stats
    python3 -c "
import json, time, datetime, sys
stats_file, genre, duration_min, station_count = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
try:
    with open(stats_file) as f:
        stats = json.load(f)
except:
    stats = {'total_sessions': 0, 'total_minutes': 0, 'total_stations': 0, 'genres': {}, 'first_session': None, 'last_session': None, 'daily': {}}

now = int(time.time())
today = datetime.date.today().isoformat()
dur = int(duration_min or '0')
sc = int(station_count or '0')

# Lifetime stats
stats['total_sessions'] = stats.get('total_sessions', 0) + 1
stats['total_minutes'] = stats.get('total_minutes', 0) + dur
stats['total_stations'] = stats.get('total_stations', 0) + sc
genres = stats.get('genres', {})
genres[genre] = genres.get(genre, 0) + dur
stats['genres'] = genres
if not stats.get('first_session'):
    stats['first_session'] = now
stats['last_session'] = now

# Daily stats
daily = stats.get('daily', {})
if today not in daily:
    daily[today] = {'sessions': 0, 'minutes': 0, 'stations': 0, 'genres': {}}
daily[today]['sessions'] = daily[today].get('sessions', 0) + 1
daily[today]['minutes'] = daily[today].get('minutes', 0) + dur
daily[today]['stations'] = daily[today].get('stations', 0) + sc
dg = daily[today].get('genres', {})
dg[genre] = dg.get(genre, 0) + dur
daily[today]['genres'] = dg
stats['daily'] = daily

# Prune daily entries older than 30 days
cutoff = (datetime.date.today() - datetime.timedelta(days=30)).isoformat()
stats['daily'] = {k: v for k, v in stats['daily'].items() if k >= cutoff}

with open(stats_file, 'w') as f:
    json.dump(stats, f, indent=2)
" "$STATS_FILE" "$genre" "${duration_min}" "${station_count}" 2>/dev/null || true
}

do_load_stats() {
    init_stats
    cat "$STATS_FILE"
}

# Combined command: volume-adjust up|down|<number>
# Does get + calculate + save + restart in a single call
do_volume_adjust() {
    local arg="$1"
    init_prefs
    local current
    current=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "30")
    [ -z "$current" ] && current="30"

    local new_vol="$current"
    local direction=""
    case "$arg" in
        up)
            new_vol=$(( current + 10 ))
            [ "$new_vol" -gt 100 ] && new_vol=100
            direction="up"
            ;;
        down)
            new_vol=$(( current - 10 ))
            [ "$new_vol" -lt 0 ] && new_vol=0
            direction="down"
            ;;
        [0-9]|[0-9][0-9]|100)
            new_vol="$arg"
            direction="set"
            ;;
        *)
            printf '{"error": "Invalid volume: %s. Use 0-100, up, or down."}\n' "$(json_escape "$arg")"
            return 1
            ;;
    esac

    json_set "$PREFS_FILE" "volume" "$new_vol"

    # Apply new volume to running player without changing station
    local applied="false"
    if is_playing; then
        # Prefer live volume change via mpv IPC socket (no restart needed)
        if [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
            echo "{\"command\":[\"set_property\",\"volume\",$new_vol]}" | socat - "$MPV_SOCK" 2>/dev/null && applied="true"
        fi
        # Fallback: kill and replay the exact same URL from state
        if [ "$applied" != "true" ] && [ -f "$STATE_FILE" ]; then
            local current_url current_genre
            current_url=$(json_get "$STATE_FILE" "url" 2>/dev/null || echo "")
            current_genre=$(json_get "$STATE_FILE" "genre" 2>/dev/null || echo "")
            if [ -n "$current_url" ] && [ -n "$current_genre" ]; then
                # Reuse do_play with a station name match so it replays the same URL
                local current_station
                current_station=$(get_stream_name "$current_genre" "$current_url" 2>/dev/null || echo "")
                if [ -n "$current_station" ]; then
                    do_play "$current_station" >/dev/null 2>&1 && applied="true"
                else
                    do_play "$current_genre" >/dev/null 2>&1 && applied="true"
                fi
            fi
        fi
    fi

    # Build human-readable message
    local message=""
    if [ "$new_vol" -gt "$current" ]; then
        message="Increased volume from $current to $new_vol"
    elif [ "$new_vol" -lt "$current" ]; then
        message="Decreased volume from $current to $new_vol"
    else
        message="Volume unchanged at $new_vol"
    fi

    cat <<EOF
{
  "direction": "$direction",
  "previous": "$current",
  "volume": "$new_vol",
  "applied": "$applied",
  "message": "$message"
}
EOF
}

# Combined command: full-stats
# Returns both session status and lifetime stats in one JSON
do_full_stats() {
    init_stats
    local status_json lifetime_json
    status_json=$(do_status)
    lifetime_json=$(cat "$STATS_FILE")

    cat <<EOF
{
  "session": $status_json,
  "lifetime": $lifetime_json
}
EOF
}

# Combined command: full-prefs
# Returns prefs with station names resolved (no need to read sources.yml separately)
do_full_prefs() {
    init_prefs
    local prefs_json
    prefs_json=$(cat "$PREFS_FILE")

    # Resolve favorite station URLs to names
    local resolved_favs=""
    if command -v python3 &>/dev/null && [ -f "$STATIONS_FILE" ]; then
        resolved_favs=$(python3 -c "
import json, sys
stations_file, prefs_file = sys.argv[1], sys.argv[2]
try:
    import yaml
    with open(stations_file) as f:
        sources = yaml.safe_load(f)
except ImportError:
    with open(stations_file) as f:
        text = f.read()
    sources = {}
    current_genre = None
    current_item = {}
    in_stations = False
    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        if indent == 0 and stripped.endswith(':'):
            if current_item and current_genre:
                sources.setdefault(current_genre, {}).setdefault('stations', []).append(current_item)
                current_item = {}
            current_genre = stripped[:-1]
            sources[current_genre] = {'stations': []}
            in_stations = False
        elif indent == 2 and stripped.startswith('stations:'):
            in_stations = True
        elif in_stations and indent == 4 and stripped.startswith('- name:'):
            if current_item and current_genre:
                sources[current_genre]['stations'].append(current_item)
            current_item = {'name': stripped.split(':', 1)[1].strip()}
        elif in_stations and indent == 6 and stripped.startswith('url:'):
            current_item['url'] = stripped.split(': ', 1)[1].strip()
        elif in_stations and indent == 6 and stripped.startswith('description:'):
            current_item['description'] = stripped.split(': ', 1)[1].strip()
    if current_item and current_genre:
        sources.setdefault(current_genre, {}).setdefault('stations', []).append(current_item)

with open(prefs_file) as f:
    prefs = json.load(f)

url_to_name = {}
for genre, genre_data in sources.items():
    stations = genre_data.get('stations', []) if isinstance(genre_data, dict) else genre_data
    for s in stations:
        url_to_name[s.get('url','')] = s.get('name','')

favs = prefs.get('favorite_stations', {})
resolved = {}
for genre, url in favs.items():
    name = url_to_name.get(url, url)
    resolved[genre] = name

print(json.dumps(resolved))
" "$STATIONS_FILE" "$PREFS_FILE" 2>/dev/null || echo "{}")
    else
        resolved_favs="{}"
    fi

    cat <<EOF
{
  "prefs": $prefs_json,
  "favorite_names": $resolved_favs
}
EOF
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
            python3 -c "import json,sys; print(int(json.load(sys.stdin).get('data',50)))" 2>/dev/null || echo "50")
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
                env _CM_URL="$win_path" powershell.exe -NoProfile -Command "
                    Add-Type -AssemblyName PresentationCore
                    \$p = New-Object System.Windows.Media.MediaPlayer
                    \$p.Open([Uri]\$env:_CM_URL)
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
    station=$(echo "$play_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get(sys.argv[1],''))" "station" 2>/dev/null || echo "")
    genre_out=$(echo "$play_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get(sys.argv[1],''))" "genre" 2>/dev/null || echo "")

    printf '{"status": "pomodoro_started", "duration_minutes": %d, "genre": "%s", "station": "%s"}\n' \
        "$minutes" "$(json_escape "$genre_out")" "$(json_escape "$station")"
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

    printf '{"status": "%s", "duration_minutes": %d, "remaining_minutes": %d, "remaining_seconds": %d}\n' \
        "$(json_escape "$pomo_status")" "$duration_minutes" "$remaining_minutes" "$remaining_seconds"
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
# Easter egg: faaah sound effect
# ============================================================================

do_faaah() {
    # Only trigger if music is currently playing
    if ! is_playing; then
        echo '{"triggered": false, "reason": "not_playing"}'
        return 0
    fi

    local faaah_file="$ASSETS_DIR/faaah.mp3"
    if [ ! -f "$faaah_file" ]; then
        echo '{"triggered": false, "reason": "missing_file"}'
        return 1
    fi

    local player
    player=$(detect_player)
    local pid
    pid=$(get_pid)
    local volume
    volume=$(json_get "$PREFS_FILE" "volume" 2>/dev/null || echo "30")
    [ -z "$volume" ] && volume="30"

    # --- Fade out current music ---
    if [ "$player" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
        # Smooth fade via mpv IPC
        for pct in 70 40 15 0; do
            local vol=$(( volume * pct / 100 ))
            echo "{\"command\":[\"set_property\",\"volume\",$vol]}" | socat - "$MPV_SOCK" 2>/dev/null || true
            sleep 0.3
        done
        # Pause mpv (keeps stream connection alive)
        echo '{"command":["set_property","pause",true]}' | socat - "$MPV_SOCK" 2>/dev/null || true
    else
        # For ffplay and others: send SIGSTOP to pause the process
        kill -STOP "$pid" 2>/dev/null || true
    fi

    # --- Play the faaah ---
    case "$player" in
        mpv)        mpv --no-video --really-quiet --volume="$volume" "$faaah_file" 2>/dev/null ;;
        ffplay)     ffplay -nodisp -autoexit -volume "$volume" "$faaah_file" 2>/dev/null ;;
        afplay)
            local vol_float
            vol_float=$(normalize_volume "$volume" "afplay")
            afplay -v "$vol_float" "$faaah_file" 2>/dev/null ;;
        play)
            local vol_float
            vol_float=$(normalize_volume "$volume" "play")
            play -v "$vol_float" "$faaah_file" 2>/dev/null ;;
        mpv.exe)
            local win_path
            win_path=$(wslpath -w "$faaah_file" 2>/dev/null || echo "$faaah_file")
            mpv.exe --no-video --really-quiet --volume="$volume" "$win_path" 2>/dev/null ;;
        powershell.exe)
            local win_path
            win_path=$(wslpath -w "$faaah_file" 2>/dev/null || echo "$faaah_file")
            env _CM_URL="$win_path" powershell.exe -NoProfile -Command "
                Add-Type -AssemblyName PresentationCore
                \$p = New-Object System.Windows.Media.MediaPlayer
                \$p.Open([Uri]\$env:_CM_URL)
                \$p.Play()
                Start-Sleep -Seconds 3
            " 2>/dev/null ;;
    esac

    # --- Fade music back in ---
    if [ "$player" = "mpv" ] && [ -S "$MPV_SOCK" ] && command -v socat &>/dev/null; then
        # Unpause and fade back in
        echo '{"command":["set_property","volume",0]}' | socat - "$MPV_SOCK" 2>/dev/null || true
        echo '{"command":["set_property","pause",false]}' | socat - "$MPV_SOCK" 2>/dev/null || true
        for pct in 15 40 70 100; do
            local vol=$(( volume * pct / 100 ))
            echo "{\"command\":[\"set_property\",\"volume\",$vol]}" | socat - "$MPV_SOCK" 2>/dev/null || true
            sleep 0.3
        done
    else
        # Resume ffplay/others from SIGSTOP
        kill -CONT "$pid" 2>/dev/null || true
    fi

    echo '{"triggered": true}'
}

# ============================================================================
# Main dispatch
# ============================================================================

case "${1:-help}" in
    play)           acquire_lock; do_play "${2:-}" ;;
    stop)           acquire_lock_or_force; do_stop ;;
    next)           acquire_lock_or_force_fast; do_next ;;
    prev)           acquire_lock_or_force_fast; do_prev ;;
    status)         do_status ;;
    detect-player)  detect_player ;;
    load-prefs)     do_load_prefs ;;
    save-pref)      do_save_pref "${2:-}" "${3:-}" ;;
    reset-prefs)    do_reset_prefs ;;
    volume-adjust)  do_volume_adjust "${2:-}" ;;
    full-stats)     do_full_stats ;;
    full-prefs)     do_full_prefs ;;
    list|list-genres)   do_list_genres ;;
    pomodoro)           do_pomodoro "${2:-25}" "${3:-}" ;;
    pomodoro-status)    do_pomodoro_status ;;
    pomodoro-stop)      do_pomodoro_stop ;;
    shuffle)            acquire_lock; do_shuffle ;;
    faaah)              do_faaah ;;
    load-stats)         do_load_stats ;;
    help|*)
        cat <<'USAGE'
claude-music controller

Commands:
  play [genre]           Start playback (lofi|jazz|classical|ambient|electronic|synthwave|lounge|indie)
  stop                   Stop playback
  pause                  Stop the music (alias for stop)
  mute                   Silence music without stopping (volume 0)
  next                   Skip to next stream in current genre
  prev                   Go back to previous station
  status                 Show current playback status
  pomodoro [min] [genre] Start focus timer (default 25 min)
  pomodoro-status        Show timer remaining
  pomodoro-stop          Cancel focus timer and stop music
  detect-player          Show detected audio player
  load-prefs             Show current preferences
  save-pref KEY VAL      Update a preference
  reset-prefs            Clear all preferences back to defaults
  volume-adjust up|down|N  Adjust volume in one step (get+save+restart)
  full-stats             Session status + lifetime stats combined
  full-prefs             Prefs with station names resolved
  load-stats             Show lifetime listening stats
  shuffle                Pick a random genre and station
  list                   List available genres
  list-genres            Alias for list
USAGE
        ;;
esac
