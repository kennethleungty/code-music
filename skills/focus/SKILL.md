---
name: focus
description: Start a pomodoro focus timer with music — fades out and chimes when time's up
disable-model-invocation: true
---

# Focus Timer

Start a pomodoro-style focus session with background music. When the timer ends, the music fades out and a gentle chime plays.

## Instructions

Parse `$ARGUMENTS` for an optional duration (in minutes) and optional genre. Examples:
- `/focus` → 25 min, default genre
- `/focus 45` → 45 min, default genre
- `/focus 30 jazz` → 30 min, jazz

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro $ARGUMENTS
```

**If it succeeds** (JSON has `"status": "pomodoro_started"`):
- Respond like: **♪ Focus mode: 25 min — lofi · Nightwave Plaza. Music will fade out when time's up. ♪**
- Use the `duration_minutes`, `genre`, and `station` fields.

**To check remaining time**, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" pomodoro-status
```

And report like: **♪ 12 min remaining in your focus session. ♪**

**Notes:**
- Users can change genre mid-session with `/play <genre>` — the timer keeps running.
- `/stop` cancels both the timer and music.
- Duration must be 1-120 minutes.
