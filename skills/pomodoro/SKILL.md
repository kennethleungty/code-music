---
name: pomodoro
description: Alias for /focus — start a pomodoro focus timer with music
disable-model-invocation: true
---

# Pomodoro Timer

Alias for `/claude-music:focus`. Start a pomodoro-style focus session with background music.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS
```

**If it succeeds** (JSON has `"status": "pomodoro_started"`):
- Respond like: **♪ Focus mode: 25 min — lofi · Nightwave Plaza. Music will fade out when time's up.**
- Use the `duration_minutes`, `genre`, and `station` fields.

**Notes:**
- Users can change genre mid-session with `/claude-music:play <genre>` — the timer keeps running.
- `/claude-music:stop` cancels both the timer and music.
- Duration must be 1-120 minutes.
