---
name: next
disable-model-invocation: true
description: "Next — skip to a different stream in the same genre"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Next Track

Skip to a different radio stream within the current genre.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" next`.

- If `"status": "playing"`: **♪ Skipped to {station} ({genre}) ♪**
- If nothing playing: **♪ Nothing playing — try `/play` to start. ♪**
