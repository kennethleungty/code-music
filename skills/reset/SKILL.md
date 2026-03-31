---
name: reset
disable-model-invocation: true
description: "Reset all music preferences back to defaults"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Reset Preferences

Clear all saved music preferences (genre, volume, favorites) back to defaults.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" reset-prefs`.

- If `"status": "reset"`: **♪ Preferences cleared! Default genre is now ambient. ♪**
