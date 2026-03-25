---
name: stats
description: Show current session stats and lifetime listening stats
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Stats

Show current session and lifetime listening stats.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" full-stats`. Response has `session` and `lifetime` objects.

**♪ Session ♪** — If playing: show genre, station, duration (calc from `session_start` unix timestamp to now), station count. If stopped: "No active session."

**♪ Lifetime ♪** — Show: sessions, total listening (convert `total_minutes` to hr/min), stations visited, top genres (sorted by min desc, show as hours if >= 60), listening since (convert `first_session` timestamp to date).

If `total_sessions` is 0: "No listening history yet — play some music! ♪"
