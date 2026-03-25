---
name: status
description: Show current music playback status — what's playing, genre, station, and volume
disable-model-invocation: true
model: haiku
effort: low
---

# Music Status

Display the current music playback state including what song is playing.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status
```

Format the JSON output nicely for the user, showing:
- **Status**: playing / stopped
- **Genre**: current genre
- **Station**: radio station name
- **Now Playing**: current track (if available from mpv metadata)
- **Volume**: current volume level
- **Player**: which audio player is being used
