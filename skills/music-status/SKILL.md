---
name: music-status
description: Show current music playback status — what's playing, genre, station, and volume
disable-model-invocation: true
---

# Music Status

Display the current music playback state including what song is playing.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status
```

Format the JSON output nicely for the user, showing:
- **Status**: playing / paused / stopped
- **Genre**: current genre
- **Station**: radio station name
- **Now Playing**: current track (if available from mpv metadata)
- **Volume**: current volume level
- **Player**: which audio player is being used
