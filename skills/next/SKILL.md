---
name: next
description: Skip to a different stream URL within the current genre (does not change genre)
disable-model-invocation: true
---

# Next Track

Switch to a different radio stream within the current genre.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" next
```

**If playback succeeds** (JSON has `"status": "playing"`):
- Respond with a short message like: **♪ Skipped to SomaFM - Lush**
- Use the `station` field from the JSON. Keep it to one line.

**If nothing is playing**, let the user know and suggest `/claude-music:play`.
