---
name: shuffle
disable-model-invocation: true
description: "Shuffle — pick a completely random genre and station"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Shuffle

Pick a completely random genre and station across the entire library and start playing.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" shuffle`.

- If `"status": "playing"`: **♪ Shuffle landed on {station} ({genre}) — let's see where this goes ♪**
- If error about no audio player: run the `install_command` (if `has_sudo` is true) or `nosudo_hint` (if false) from the JSON, then retry automatically.
