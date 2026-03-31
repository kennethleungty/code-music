---
name: prev
disable-model-invocation: true
description: "Previous — go back to the last stream you were on"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Previous Station

Go back to the previous radio station.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" prev`.

The JSON response includes `genre` and `station` fields. Use both in your reply:

- If `"status": "playing"`: **♪ Now playing {genre} — {station} ♪**
- If `"status": "error"`: **♪ No previous station — try `/next` first, then `/prev` to go back. ♪**
- If nothing playing: **♪ Nothing playing — try `/play` to start. ♪**
