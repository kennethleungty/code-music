---
name: help
description: Show how to use claude-music — available commands and genres
disable-model-invocation: true
---

# Help

Show the user a quick guide to claude-music.

## Instructions

Print the following guide directly (do not run any commands):

---

**claude-music** — background music for your coding sessions

**Playback**
- `/play [genre]` — Start music (optionally pick a genre)
- `/stop` — Stop music
- `/next` — Skip to a different stream in the same genre

**DJ**
- `/vibe` — Auto-DJ picks music based on your current session
- `/dj` — Same as vibe
- `/say <mood>` — Tell the DJ how you're feeling in your own words

**Focus**
- `/focus [min] [genre]` — Pomodoro timer with music (default 25 min). Music fades out and a chime plays when time's up.
- `/pomodoro` — Same as focus

**Info**
- `/status` — What's playing right now
- `/list` — Show available genres
- `/volume [0-100]` — Set volume, or show current if no number given
- `/stats` — See current session and lifetime listening stats
- `/prefs` — See your saved preferences and favorite stations
- `/sources` — View, add, edit, or remove streams and genres

**Genres:** lofi, jazz, classical, ambient, edm, synthwave, lounge, indie

The status bar at the bottom shows what's currently playing.
