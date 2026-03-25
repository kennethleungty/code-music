# claude-music for Cursor

Background music for your Cursor coding sessions. Lofi, jazz, classical, ambient, electronic — streaming live from the internet.

## Installation

In Cursor's Agent chat:

```
/add-plugin claude-music
```

Or search for **claude-music** in the marketplace.

## Quick Start

```
/play                # Start playing (ambient by default)
/play jazz           # Play a specific genre
/stop                # Stop the music
/vibe                # Let the AI DJ pick for you
```

## All Commands

| Command | What it does |
|---------|-------------|
| `/play [genre or station]` | Start playing by genre or station name |
| `/stop` | Stop the music and show session stats |
| `/next` | Switch to a different station (same genre) |
| `/vibe` | AI DJ reads your session and picks the best genre |
| `/say <mood>` | Tell the DJ your mood and it picks the right music |
| `/focus [min] [genre]` | Pomodoro timer with music (default 25 min) |
| `/volume [0-100]` | Set volume |
| `/status` | See what's playing |
| `/list` | List available genres |
| `/stats` | Session and lifetime listening stats |
| `/prefs` | Your saved preferences |

## Genres

lofi, jazz, classical, ambient, electronic, synthwave, lounge, indie

## Requirements

- An audio player: **mpv** (recommended) or **ffplay**
- The plugin auto-detects and offers to install one if needed

See the full [README](https://github.com/kennethleungty/claude-music#readme) for more details.
