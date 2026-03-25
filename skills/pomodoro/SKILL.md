---
name: pomodoro
disable-model-invocation: true
description: "Pomodoro — focus timer with music (alias for /focus)"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Pomodoro (alias for /focus)

Start a pomodoro focus session with music. Music fades out when time's up.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS` (args: optional minutes then optional genre).

- If `"status": "pomodoro_started"`: **♪ Focus mode: {duration_minutes} min — {genre} · {station}. Music will fade out when time's up. ♪**
