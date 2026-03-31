---
name: stop
disable-model-invocation: true
description: "Stop the music and show session stats"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Stop Music

Stop background music and show a session recap.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" stop`.

- If `"already_stopped"`: just say **♪ No music playing. ♪**
- Otherwise format a recap using the JSON fields. Use `duration_minutes` for session duration (show "< 1 min" if 0), `station_count`, `genre`, `today_sessions`, `today_minutes`, and `today_genres` (each genre with its minutes, sorted by most listened).

Output format — use this exact markdown structure:

**♪ Claude Music · Session Recap**

**This session** — {genre} for {duration_minutes} min, {station_count} station(s)

**Today so far** — {today_sessions} session(s), {today_minutes} min total ({genres list e.g. "ambient 30 min, jazz 15 min"})

*{fun one-liner that varies, e.g. "Good vibes only.", "Your ears deserved that.", "The code was better with music.", "Same time tomorrow?", "That was a vibe."}*
