---
name: pomodoro
description: Alias for /focus — start a pomodoro focus timer with music
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Pomodoro (alias for /focus)

Start a pomodoro focus session with music. Music fades out when time's up.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS` (args: optional minutes then optional genre).

- If `"status": "pomodoro_started"`: **♪ Focus mode: {duration_minutes} min — {genre} · {station}. Music will fade out when time's up. ♪**
