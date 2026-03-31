---
name: focus
disable-model-invocation: true
description: "Focus — pomodoro timer with music that fades when time's up"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Focus Timer

Start a pomodoro focus session with music. Music fades out when time's up.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS` (args: optional minutes then optional genre, e.g. `30 jazz`).

- If `"status": "pomodoro_started"`: **♪ Focus mode: {duration_minutes} min — {genre} · {station}. Music will fade out when time's up. ♪**
