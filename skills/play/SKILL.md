---
name: play
disable-model-invocation: true
description: "Play music — start or switch genre/station"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Play Music

Start background music. Optionally specify a genre or station name (e.g. `/play jazz`, `/play groove salad`).

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play $ARGUMENTS`.

- If `"status": "playing"`: **♪ Now playing {genre} — {station} ♪**
  - If `takeover` is `true`: prefix with *Switched over from another session{prev_genre ? " (was playing {prev_genre})" : ""} —* before the now-playing line
  - If `genre_reason` is `"preference"`: add *(resumed from your last session)*
  - If `genre_reason` is `"default"`: add *(default genre — use `/play <genre>` to change)*
  - If `genre_reason` is `"requested"`: no extra note needed
- If error about no audio player: run the `install_command` (if `has_sudo` is true) or `nosudo_hint` (if false) from the JSON, then retry play automatically.
- If error about both primary and fallback failing: tell the user and suggest trying `/next` or a different genre.

Genres: lofi, jazz, classical, ambient, electronic, synthwave, lounge, indie. Also accepts station names (e.g. "groove salad").
