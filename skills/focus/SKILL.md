---
name: focus
description: Start a pomodoro focus timer with music — fades out and chimes when time's up
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Focus Timer

Start a pomodoro focus session with music. Music fades out when time's up.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS` (args: optional minutes then optional genre, e.g. `30 jazz`).

- If `"status": "pomodoro_started"`: **♪ Focus mode: {duration_minutes} min — {genre} · {station}. Music will fade out when time's up. ♪**
