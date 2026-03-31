---
name: status
disable-model-invocation: true
description: "Status — what's playing, genre, station, and volume"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Music Status

Show the current music playback state.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status` and format the JSON showing: Status, Genre, Station, Now Playing (if available), Volume, and Player.
