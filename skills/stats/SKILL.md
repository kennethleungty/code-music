---
name: stats
disable-model-invocation: true
description: "Stats — session and lifetime listening stats"
model: haiku
effort: low
allowed-tools: Bash
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Stats

Show current session and lifetime listening stats.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" full-stats`. Response has `session` and `lifetime` objects.

**♪ Session ♪** — If playing: show genre, station, duration (calc from `session_start` unix timestamp to now), station count. If stopped: "No active session."

**♪ Lifetime ♪** — Show: sessions, total listening (convert `total_minutes` to hr/min), stations visited, top genres (sorted by min desc, show as hours if >= 60), listening since (convert `first_session` timestamp to date).

If `total_sessions` is 0: "No listening history yet — play some music! ♪"
