---
name: volume
description: Set the music playback volume (0-100), show current volume, or adjust with up/down
disable-model-invocation: true
model: haiku
effort: low
---

# Set Volume

Adjust the music volume. Accepts a number from 0 (mute) to 100 (max), or `up`/`down` to adjust by 10.

## Instructions

**If no argument is provided** (`$ARGUMENTS` is empty), show the current volume:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status
```

Read the `volume` field from the JSON and respond like: **♪ Volume: 40/100 ♪**

**If `up`, `down`, or a number is provided**, use the combined command (handles get + save + restart in one call):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" volume-adjust $ARGUMENTS
```

Read the JSON response and respond based on `direction`:
- `"up"`: **♪ Volume up: {volume}/100 ♪**
- `"down"`: **♪ Volume down: {volume}/100 ♪**
- `"set"`: **♪ Volume set to {volume}/100 ♪**
