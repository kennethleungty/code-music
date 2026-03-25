---
name: play
description: Start or restart background music playback with optional genre or station name
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Play Music

Start background music. Optionally specify a genre or station name (e.g. `/play jazz`, `/play groove salad`).

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play $ARGUMENTS`.

- If `"status": "playing"`: **♪ Now playing {genre} — {station} ♪**
- If error about no audio player: run the `install_command` (if `has_sudo` is true) or `nosudo_hint` (if false) from the JSON, then retry play automatically.

Genres: lofi, jazz, classical, ambient, edm, synthwave, lounge, indie. Also accepts station names (e.g. "groove salad").
