#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Platform detection for claude-music
# Outputs JSON with platform info for other scripts to consume
# ============================================================================

detect_platform() {
    local os="unknown"
    local distro=""
    local pkg_manager=""
    local audio_backend=""
    local audio_ready="false"
    local is_wsl="false"
    local wsl_version=""

    # Detect OS
    case "$(uname -s)" in
        Darwin)
            os="macos"
            # Check for Homebrew
            if command -v brew &>/dev/null; then
                pkg_manager="brew"
            fi
            # macOS always has audio
            audio_backend="coreaudio"
            audio_ready="true"
            ;;
        Linux)
            os="linux"

            # Check for WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                is_wsl="true"
                # Detect WSL version
                if [ -f /proc/sys/fs/binfmt_misc/WSLInterop-late ] || \
                   grep -q "WSL2" /proc/version 2>/dev/null; then
                    wsl_version="2"
                else
                    wsl_version="1"
                fi
            fi

            # Detect distro
            if [ -f /etc/os-release ]; then
                distro=$(. /etc/os-release && echo "${ID:-unknown}")
            fi

            # Detect package manager
            if command -v apt &>/dev/null; then
                pkg_manager="apt"
            elif command -v dnf &>/dev/null; then
                pkg_manager="dnf"
            elif command -v pacman &>/dev/null; then
                pkg_manager="pacman"
            elif command -v apk &>/dev/null; then
                pkg_manager="apk"
            elif command -v zypper &>/dev/null; then
                pkg_manager="zypper"
            elif command -v brew &>/dev/null; then
                pkg_manager="brew"
            fi

            # Detect audio backend
            if command -v pactl &>/dev/null && pactl info &>/dev/null 2>&1; then
                audio_backend="pulseaudio"
                audio_ready="true"
            elif command -v pipewire &>/dev/null && pw-cli info 0 &>/dev/null 2>&1; then
                audio_backend="pipewire"
                audio_ready="true"
            elif [ "$is_wsl" = "true" ]; then
                # WSL2 with WSLg has PulseAudio via /mnt/wslg
                if [ -S "/mnt/wslg/PulseServer" ] || [ -n "${PULSE_SERVER:-}" ]; then
                    audio_backend="wslg-pulse"
                    audio_ready="true"
                else
                    audio_backend="none"
                    audio_ready="false"
                fi
            else
                # Check ALSA as last resort
                if command -v aplay &>/dev/null && aplay -l &>/dev/null 2>&1; then
                    audio_backend="alsa"
                    audio_ready="true"
                else
                    audio_backend="none"
                    audio_ready="false"
                fi
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os="windows"
            # Git Bash / MSYS2 / Cygwin
            if command -v choco &>/dev/null; then
                pkg_manager="choco"
            elif command -v scoop &>/dev/null; then
                pkg_manager="scoop"
            elif command -v winget.exe &>/dev/null || command -v winget &>/dev/null; then
                pkg_manager="winget"
            fi
            audio_backend="wasapi"
            audio_ready="true"
            ;;
    esac

    # Detect available audio players
    local players=""
    for p in mpv ffplay afplay play; do
        if command -v "$p" &>/dev/null; then
            if [ -n "$players" ]; then
                players="$players,$p"
            else
                players="$p"
            fi
        fi
    done
    # On Windows/WSL, also check for mpv.exe / PowerShell
    if [ "$os" = "windows" ] || [ "$is_wsl" = "true" ]; then
        if command -v mpv.exe &>/dev/null; then
            if [ -n "$players" ]; then
                players="$players,mpv.exe"
            else
                players="mpv.exe"
            fi
        fi
        if command -v powershell.exe &>/dev/null; then
            if [ -n "$players" ]; then
                players="$players,powershell.exe"
            else
                players="powershell.exe"
            fi
        fi
    fi

    # Detect yt-dlp (needed for YouTube stream support)
    local has_ytdlp="false"
    if command -v yt-dlp &>/dev/null; then
        has_ytdlp="true"
    fi

    cat <<EOF
{
  "os": "$os",
  "distro": "$distro",
  "is_wsl": $is_wsl,
  "wsl_version": "$wsl_version",
  "pkg_manager": "$pkg_manager",
  "audio_backend": "$audio_backend",
  "audio_ready": $audio_ready,
  "available_players": "$players",
  "has_ytdlp": $has_ytdlp
}
EOF
}

detect_platform
