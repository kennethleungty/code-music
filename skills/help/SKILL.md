---
name: help
disable-model-invocation: true
description: "Help — all the commands and genres you can use"
model: haiku
effort: low
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Help

Show the user a quick guide to claude-music.

## Instructions

Print the following guide directly (do not run any commands):

---

**claude-music** — background music for your coding sessions

**Playback**
- `/play [genre]` — Start music (optionally pick a genre)
- `/stop` — Stop music
- `/pause` — Stop music (alias for /stop)
- `/mute` — Silence the music without stopping (volume 0)
- `/next` — Skip to a different stream in the same genre
- `/prev` — Go back to the previous station

**DJ**
- `/vibe` — Auto-DJ picks music based on your current session
- `/dj` — Same as vibe
- `/mood <feeling>` — Tell the DJ how you're feeling in your own words

**Focus**
- `/focus [min] [genre]` — Pomodoro timer with music (default 25 min). Music fades out and a chime plays when time's up.
- `/pomodoro` — Same as focus

**Info**
- `/status` — What's playing right now
- `/list` — Show available genres and their stations
- `/volume [0-100]` — Set volume, or show current if no number given
- `/stats` — See current session and lifetime listening stats
- `/prefs` — See your saved preferences and favorite stations
- `/reset` — Clear all preferences back to defaults
- `/sources` — View, add, edit, or remove streams and genres

**Other**
- `/feedback` — Open GitHub Issues to share feedback or report a bug

**Genres:** lofi, jazz, classical, ambient, electronic, synthwave, lounge, indie

The status bar at the bottom shows what's currently playing.
