---
name: set-genre
description: Change the music genre and restart playback (lofi, jazz, classical, ambient)
disable-model-invocation: true
---

# Set Genre

Change the music genre, save the preference, and restart playback.

## Instructions

1. Save the genre preference:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" save-pref genre "$ARGUMENTS"
```

2. Restart playback with the new genre:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play "$ARGUMENTS"
```

Report the genre change and new station to the user.

Available genres: lofi, jazz, classical, ambient.
