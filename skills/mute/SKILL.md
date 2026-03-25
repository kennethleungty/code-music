---
name: mute
description: Stop background music playback and show session stats (alias for /stop)
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Mute (alias for /stop)

Stop background music and show a nice recap. Same behavior as /stop.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" stop`.

**If `"status": "already_stopped"`**: just say **♪ No music playing. ♪**

**If `"status": "stopped"`**, format the output as a recap card like this (use the exact box style):

```
┌─────────────────────────────────────┐
│  ♪  claude-music · session recap    │
├─────────────────────────────────────┤
│                                     │
│  This session                       │
│  ─────────────                      │
│  Genre:     {genre}                 │
│  Duration:  {duration_minutes} min  │
│  Stations:  {station_count}         │
│                                     │
│  Today so far                       │
│  ────────────                       │
│  Sessions:  {today_sessions}        │
│  Listening: {today_minutes} min     │
│  Genres:    {genre} ({min} min)     │
│                                     │
│  {fun one-liner}                    │
│                                     │
└─────────────────────────────────────┘
```

Rules:
- Use the JSON fields: `duration_minutes`, `station_count`, `genre`, `today_sessions`, `today_minutes`, `today_genres`
- For `today_genres`, list each genre with its minutes (e.g. "ambient (30 min), jazz (15 min)")
- End with a fun, warm one-liner that varies each time (e.g. "Good vibes only.", "Hope that hit the spot.", "Your ears deserved that.", "Solid session, legend.", "Until next time.")
- If `duration_minutes` is 0, show "< 1 min" instead
- Keep the box width consistent — pad lines with spaces to align the right border
