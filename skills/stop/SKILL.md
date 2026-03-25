---
name: stop
description: Stop background music playback and show session stats
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Stop Music

Stop background music and show session + today's stats in a fun, friendly way.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" stop`.

The JSON response includes both session and today's cumulative fields.

**If `"status": "stopped"`**, show two sections:

**♪ Session wrapped ♪** — This session's stats: genre, duration (`duration_minutes`), stations visited (`station_count`). Add a fun one-liner comment (e.g. "Solid focus sesh!", "That was a good run.", "Hope the vibes were right."). Skip if duration is 0.

**♪ Today so far ♪** — Today's cumulative: total sessions (`today_sessions`), total minutes (`today_minutes`), genres listened to (`today_genres` — show each genre with its minutes). Keep it short and warm.

**If `"status": "already_stopped"`**: **♪ No music playing. ♪**
