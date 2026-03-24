---
name: play
description: Start or restart background music playback with optional genre (lofi, jazz, classical, ambient)
disable-model-invocation: true
---

# Play Music

Start background music playback. Optionally specify a genre.

## Instructions

Run the music controller:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play $ARGUMENTS
```

Report the JSON output to the user. If it shows an error about no audio player, suggest installing mpv:
- macOS: `brew install mpv`
- Linux: `apt install mpv` or `pacman -S mpv`

Available genres: lofi (default), jazz, classical, ambient.
