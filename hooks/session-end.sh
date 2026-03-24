#!/usr/bin/env bash
set -euo pipefail

# SessionEnd hook for claude-music plugin
# Stops music playback when the session ends

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONTROLLER="$PLUGIN_ROOT/scripts/music-controller.sh"

# Stop playback if running
"$CONTROLLER" stop >/dev/null 2>&1 || true

# SessionEnd hooks don't support hookSpecificOutput — output empty JSON
printf '{}\n'

exit 0
