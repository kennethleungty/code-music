---
name: status
description: Show current music playback status — what's playing, genre, station, and volume
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Music Status

Show the current music playback state.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status` and format the JSON showing: Status, Genre, Station, Now Playing (if available), Volume, and Player.
