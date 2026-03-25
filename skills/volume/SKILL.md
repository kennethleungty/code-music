---
name: volume
disable-model-invocation: true
description: "Volume — set, get, or nudge the music volume up/down"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Volume

Adjust music volume (0-100), or `up`/`down` to adjust by 10.

- If `$ARGUMENTS` is empty: run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status` → **♪ Volume: {volume}/100 ♪**
- If `up`, `down`, or a number: run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" volume-adjust $ARGUMENTS` → use the `message` field from the JSON output verbatim: **♪ {message} ♪**
