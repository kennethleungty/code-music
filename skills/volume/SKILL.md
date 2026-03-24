---
name: volume
description: Set the music playback volume (0-100)
disable-model-invocation: true
---

# Set Volume

Adjust the music volume. Accepts a number from 0 (mute) to 100 (max).

## Instructions

1. Save the volume preference:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" save-pref volume "$ARGUMENTS"
```

2. If music is currently playing, restart playback to apply the new volume:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play
```

3. Report the new volume level to the user.

If no number is provided, show the current volume:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status
```
