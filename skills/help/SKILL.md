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
- `/claude-music:play [genre]` — Start music (optionally pick a genre)
- `/claude-music:stop` — Stop music
- `/claude-music:next` — Skip to a different stream in the same genre

**DJ**
- `/claude-music:vibe` — Auto-DJ picks music based on your current session
- `/claude-music:dj` — Same as vibe
- `/claude-music:say <mood>` — Tell the DJ how you're feeling in your own words

**Focus**
- `/claude-music:focus [min] [genre]` — Pomodoro timer with music (default 25 min). Music fades out and a chime plays when time's up.
- `/claude-music:pomodoro` — Same as focus

**Info**
- `/claude-music:status` — What's playing right now
- `/claude-music:list` — Show available genres
- `/claude-music:volume [0-100]` — Set volume, or show current if no number given
- `/claude-music:sources` — View, add, edit, or remove streams and genres

**Genres:** lofi, jazz, classical, ambient, edm

The status bar at the bottom shows what's currently playing.
