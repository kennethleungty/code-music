---
name: volume
description: Set the music playback volume (0-100), or show current volume if no argument
disable-model-invocation: true
---

# Set Volume

Adjust the music volume. Accepts a number from 0 (mute) to 100 (max).

## Instructions

**If no argument is provided** (`$ARGUMENTS` is empty), show the current volume:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status
```

Read the `volume` field from the JSON and respond like: **Volume: 70/100**

**If a number is provided:**

1. Save the volume preference:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" save-pref volume "$ARGUMENTS"
```

2. If music is currently playing, restart playback to apply the new volume:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play
```

3. Respond with a short confirmation like: **Volume set to 50/100**
