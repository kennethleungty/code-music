---
name: mute
disable-model-invocation: true
description: "Mute — silence the music without stopping the stream"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Mute

Set volume to 0 — the stream keeps playing silently. Use `/volume up` or `/volume <number>` to unmute.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" volume-adjust 0`.

Use the `message` field from the JSON output: **♪ {message} ♪**

Add: *Use `/volume up` or `/volume <number>` to unmute.*
