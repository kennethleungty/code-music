#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Audio setup helper for claude-music
# Handles platform-specific audio configuration (especially WSL)
# Usage: setup-audio.sh <action>
#   check     - Check if audio is working
#   fix-wsl   - Configure WSL audio (PulseAudio/PipeWire)
#   test      - Play a test tone to verify audio works
# ============================================================================

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

check_audio() {
    # Try to detect if audio output is actually functional
    local os
    os=$(uname -s)

    case "$os" in
        Darwin)
            # macOS always has audio
            echo '{"audio_working": true, "method": "coreaudio"}'
            return 0
            ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                # WSL — check for WSLg PulseAudio
                if [ -S "/mnt/wslg/PulseServer" ]; then
                    echo '{"audio_working": true, "method": "wslg"}'
                    return 0
                elif [ -n "${PULSE_SERVER:-}" ] && pactl info &>/dev/null 2>&1; then
                    echo '{"audio_working": true, "method": "pulseaudio-bridge"}'
                    return 0
                else
                    echo '{"audio_working": false, "method": "none", "hint": "WSL audio not configured. Run setup-audio.sh fix-wsl"}'
                    return 1
                fi
            else
                # Native Linux
                if pactl info &>/dev/null 2>&1; then
                    echo '{"audio_working": true, "method": "pulseaudio"}'
                    return 0
                elif pw-cli info 0 &>/dev/null 2>&1; then
                    echo '{"audio_working": true, "method": "pipewire"}'
                    return 0
                elif aplay -l &>/dev/null 2>&1; then
                    echo '{"audio_working": true, "method": "alsa"}'
                    return 0
                else
                    echo '{"audio_working": false, "method": "none", "hint": "No audio backend detected"}'
                    return 1
                fi
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (Git Bash) always has audio
            echo '{"audio_working": true, "method": "wasapi"}'
            return 0
            ;;
    esac

    echo '{"audio_working": false, "method": "unknown"}'
    return 1
}

fix_wsl() {
    echo "=== WSL Audio Setup ==="
    echo ""

    # Check WSL version
    local wsl_version="unknown"
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop-late ] || \
       grep -q "WSL2" /proc/version 2>/dev/null; then
        wsl_version="2"
    else
        wsl_version="1"
    fi

    echo "WSL version: $wsl_version"

    # Check for WSLg (Windows 11+, WSL2)
    if [ -S "/mnt/wslg/PulseServer" ]; then
        echo "WSLg detected — PulseAudio already available via /mnt/wslg/PulseServer"
        echo "Audio should work. Setting PULSE_SERVER if not set..."

        if [ -z "${PULSE_SERVER:-}" ]; then
            echo ""
            echo "Add this to your ~/.bashrc or ~/.zshrc:"
            echo "  export PULSE_SERVER=unix:/mnt/wslg/PulseServer"
            echo ""
            echo "Then restart your shell or run:"
            echo "  source ~/.bashrc"
        fi

        echo '{"fixed": true, "method": "wslg"}'
        return 0
    fi

    # No WSLg — need PulseAudio bridge
    echo ""
    echo "WSLg not detected. You need PulseAudio on the Windows side."
    echo ""
    echo "=== Option 1: Windows 11 + WSL2 (recommended) ==="
    echo "Update WSL to get WSLg with built-in audio:"
    echo "  1. Open PowerShell as Admin on Windows"
    echo "  2. Run: wsl --update"
    echo "  3. Run: wsl --shutdown"
    echo "  4. Restart your WSL session"
    echo ""
    echo "=== Option 2: Manual PulseAudio bridge ==="
    echo "  1. Download PulseAudio for Windows:"
    echo "     https://www.freedesktop.org/wiki/Software/PulseAudio/Ports/Windows/Support/"
    echo "  2. Extract and run pulseaudio.exe on Windows"
    echo "  3. In WSL, add to ~/.bashrc:"
    echo "     export PULSE_SERVER=tcp:\$(cat /etc/resolv.conf | grep nameserver | awk '{print \$2}')"
    echo "  4. Install PulseAudio client in WSL:"
    echo "     sudo apt install -y pulseaudio-utils"
    echo ""

    # Check if pulseaudio-utils is installed
    if ! command -v pactl &>/dev/null; then
        echo "PulseAudio client tools not installed in WSL."
        echo "Install with: sudo apt install -y pulseaudio-utils"
    fi

    echo '{"fixed": false, "method": "manual_steps_shown"}'
    return 1
}

test_audio() {
    echo "Testing audio output..."

    # Try different methods to produce a test sound
    if command -v paplay &>/dev/null; then
        # Try PulseAudio test
        if paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null; then
            echo "Audio works (PulseAudio)"
            return 0
        fi
    fi

    if command -v speaker-test &>/dev/null; then
        echo "Playing 2-second test tone..."
        timeout 2 speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 && echo "Audio works (ALSA)" && return 0
    fi

    if command -v mpv &>/dev/null; then
        echo "Playing test via mpv..."
        # Generate a short beep using mpv's tone generator
        timeout 2 mpv --no-video --really-quiet "av://lavfi/sine=frequency=440:duration=1" 2>/dev/null && echo "Audio works (mpv)" && return 0
    fi

    if command -v ffplay &>/dev/null; then
        echo "Playing test via ffplay..."
        timeout 2 ffplay -f lavfi -i "sine=frequency=440:duration=1" -autoexit -nodisp 2>/dev/null && echo "Audio works (ffplay)" && return 0
    fi

    if [ "$(uname -s)" = "Darwin" ] && command -v afplay &>/dev/null; then
        # macOS — play system sound
        afplay /System/Library/Sounds/Ping.aiff 2>/dev/null && echo "Audio works (afplay)" && return 0
    fi

    if command -v powershell.exe &>/dev/null; then
        echo "Playing test via PowerShell..."
        powershell.exe -Command "[console]::beep(440,1000)" 2>/dev/null && echo "Audio works (PowerShell)" && return 0
    fi

    echo "Could not play test audio. Audio may not be configured."
    return 1
}

# Main dispatch
case "${1:-check}" in
    check)    check_audio ;;
    fix-wsl)  fix_wsl ;;
    test)     test_audio ;;
    *)
        echo "Usage: setup-audio.sh {check|fix-wsl|test}"
        exit 1
        ;;
esac
