---
name: now
disable-model-invocation: true
description: "Now playing — see the current song, genre, and station"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Now Playing

Show the current music playback state.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status` and format the JSON showing: Status, Genre, Station, Now Playing (if available), Volume, and Player.
