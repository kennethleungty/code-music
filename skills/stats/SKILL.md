---
name: stats
description: Show current session stats and lifetime listening stats
disable-model-invocation: true
model: haiku
effort: low
---

# Stats

Show both the current session and lifetime listening stats in one view.

## Instructions

Run the combined command (returns both session and lifetime stats in one call):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" full-stats
```

The response has `session` and `lifetime` objects. Display everything in a friendly format:

**♪ Session ♪**

If music is currently playing, show:
- **Playing:** lofi — Nightwave Plaza
- **Duration:** 23 min
- **Stations this session:** 2

Calculate session duration from `session_start` (unix timestamp) to now. If nothing is playing, say "No active session."

**♪ Lifetime ♪**

- **Sessions:** 12
- **Total listening:** 8 hr 30 min
- **Stations visited:** 24
- **Top genres:** lofi (5 hr), jazz (2 hr), ambient (1 hr)
- **Listening since:** Mar 15, 2026

Convert `total_minutes` to hours and minutes. Convert `first_session` from unix timestamp to a readable date. Show genres from the `genres` object sorted by minutes descending, formatted as hours if >= 60 min.

If no stats yet (total_sessions is 0), say "No listening history yet — play some music! ♪"
