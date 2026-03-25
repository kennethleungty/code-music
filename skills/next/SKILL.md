---
name: next
description: Skip to a different stream URL within the current genre (does not change genre)
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Next Track

Skip to a different radio stream within the current genre.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" next`.

- If `"status": "playing"`: **♪ Skipped to {station} ♪**
- If nothing playing: **♪ Nothing playing — try `/play` to start. ♪**
