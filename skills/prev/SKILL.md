---
name: prev
disable-model-invocation: true
description: "Previous — go back to the last stream you were on"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Previous Station

Go back to the previous radio station.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" prev`.

- If `"status": "playing"`: **♪ Back to {station} ({genre}) ♪**
- If `"status": "error"`: **♪ No previous station — try `/next` first, then `/prev` to go back. ♪**
- If nothing playing: **♪ Nothing playing — try `/play` to start. ♪**
