---
name: mute
description: Stop background music playback and show session stats (alias for /stop)
disable-model-invocation: true
model: haiku
effort: low
---

# Mute Music

Alias for `/stop`. Stop the currently playing background music and show session stats.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" stop
```

**If music was playing** (JSON has `"status": "stopped"` with stats):
- Show a short wrap-up using the `genre`, `duration_minutes`, and `station_count` fields.
- Format like: **♪ Muted. You listened to jazz for 47 min across 3 stations. Good session. ♪**
- If duration is 0 min, just say: **♪ Muted. ♪**
- Keep it to one line, warm tone.

**If nothing was playing** (`"status": "already_stopped"`):
- Just say: **♪ No music playing. ♪**
