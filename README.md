<p align="center">
  <img src="assets/logo.png" alt="Code Music" width="400">
</p>

##Enjoy Music in your Coding Agent Sessions

Code Music plays lovely background music while your AI coding agents do the heavy lifting. Lofi, jazz, classical, ambient, and more — streaming live from the internet, right in your terminal.

No setup, no accounts, no ads. Just install and play.


## Installation

> **Note:** Installation differs by platform. Claude Code and Cursor have built-in plugin marketplaces. OpenCode requires manual setup.

### Claude Code (Official Marketplace)

```bash
/plugin install code-music
```

### Cursor

In Cursor's Agent chat:

```
/add-plugin code-music
```

Or search for **code-music** in the marketplace. [Detailed docs →](docs/README.cursor.md)

### OpenCode

Add to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["code-music@git+https://github.com/kennethleungty/code-music.git"]
}
```

Restart OpenCode. [Detailed docs →](docs/README.opencode.md)

### Verify Installation

Start a new session in your chosen platform and try `/play`. Background music should start streaming immediately. You can also try `/vibe` to let the AI DJ pick a genre based on your current session, or `/help` to see all available commands.

> Don't have an audio player installed? No worries — the plugin detects this and walks you through installing one automatically.

## Quick Start

```
/play                # Start playing (ambient by default)
/play jazz           # Play a specific genre
/stop                # Stop the music
```

Or let the AI DJ pick for you:

```
/vibe                            # DJ reads your session and picks automatically
/mood feeling tired, need energy  # Tell the DJ your mood in your own words
```

Or start a focus session with a timer:

```
/focus              # 25 min pomodoro — music fades out and chimes when done
/focus 45 ambient   # 45 min with ambient music
```

## Your AI DJ

The plugin includes our resident DJ agent (DJ Ken) that picks the right music for you. He learns your preferences over time — the more you use it, the better it gets.

- **`/vibe`** — The DJ reads your current session automatically. Debugging? It switches to lofi. Deep in a code review? Classical kicks in. No input needed, it figures it out.
- **`/mood <feeling>`** — Tell the DJ what you want in your own words. "feeling tired, need energy", "calm me down", "something retro and fun".
- **`/prefs`** — See what the plugin has learned about your preferences.

## Genres

| Genre | Vibe | Great for | Stations |
|-------|------|-----------|----------|
| **lofi** | Chill downtempo beats, mellow vibes | Focused coding, debugging, writing tests | 2 |
| **jazz** | Smooth jazz, bossa nova, instrumental | Building features, refactoring | 4 |
| **classical** | Orchestral, chamber music, deep focus | Code review, reading, research | 4 |
| **ambient** | Atmospheric drones, space music | Brainstorming, design, creative work | 5 |
| **electronic** | Electronic, trance, IDM, dubstep, trip-hop | Shipping sprints, high-energy sessions | 6 |
| **synthwave** | Retro-futuristic, 80s-inspired | Late night coding, nostalgic vibes | 4 |
| **lounge** | Cinematic, spy-movie elegance | Demos, presentations, smooth backdrop | 2 |
| **indie** | Indie pop, folk, dream pop | Creative writing, docs, warm sessions | 4 |

Each genre has multiple stations. Use `/next` to cycle through them.

## All Commands

| Command | What it does |
|---------|-------------|
| `/play [genre or station]` | Start playing by genre or station name |
| `/stop` | Stop the music and show session stats |
| `/next` | Switch to a different station (same genre) |
| `/prev` | Go back to the previous station |
| `/pause` | Stop the music (alias for `/stop`) |
| `/mute` | Silence the music without stopping the stream (volume 0) |
| `/vibe` | AI DJ reads your session and picks the best genre |
| `/dj` | Same as `/vibe` |
| `/mood <feeling>` | Tell the DJ how you're feeling and it picks the right music |
| `/focus [min] [genre]` | Pomodoro timer with music (default 25 min) |
| `/pomodoro` | Same as `/focus` |
| `/volume [0-100]` | Set volume, or show current if no number given |
| `/status` | See what's playing right now |
| `/list` | List available genres and their stations |
| `/stats` | See current session and lifetime listening stats |
| `/prefs` | See your saved preferences and favorite stations |
| `/reset` | Clear all preferences back to defaults |
| `/sources` | View, add, edit, or remove streams |
| `/feedback` | Report a bug or share feedback on GitHub |
| `/help` | Show help |

## Focus Timer

Start a pomodoro session with background music. When the timer ends, the music fades out and a chime plays.

```
/focus              # 25 min, current genre
/focus 45 ambient   # 45 min of ambient
```

## Now Playing

The status line at the bottom of your terminal shows what's currently playing — genre, station name, track title, and pomodoro countdown when active. Always visible, never scrolls away.

## Your Preferences

Your settings are saved automatically and persist locally across sessions:

- **Genre** — your preferred default (ambient by default when fresh start)
- **Volume** — 0 to 100 (changed via `/volume`)

## Works Everywhere

| Platform | How it plays |
|----------|-------------|
| **macOS** | mpv (via Homebrew) or built-in afplay |
| **Linux** | mpv (via apt, dnf, pacman, etc.) |
| **WSL2** | mpv inside WSL (with WSLg audio) or Windows-side mpv.exe |
| **Windows** | mpv (via winget, scoop, or chocolatey) |

The plugin auto-detects your platform and available audio players. If nothing is installed, it offers to set one up for you.

## Radio Stations

All streams are free, ad-free, and require no account.

- **Lofi** — Nightwave Plaza, Groove Salad
- **Jazz** — SomaFM Fluid, Bossa Beyond, FIP Jazz, WDCB Jazz
- **Classical** — All Classical Portland, WWFM, France Musique, Iowa Public Radio
- **Ambient** — SomaFM Drone Zone, Deep Space One, Mission Control, Dark Zone, Stereoscenic Ambient
- **Electronic** — Beat Blender, SomaFM The Trip, Cliqhop IDM, Dub Step Beyond, Suburbs of Goa, Groove Salad Classic
- **Synthwave** — SomaFM Synphaera, Vaporwaves, DEF CON Radio, Space Station Soma
- **Lounge** — SomaFM Secret Agent, Illinois Street Lounge
- **Indie** — SomaFM Lush, Indie Pop Rocks, Folk Forward, BAGeL Radio

Want to add your own stations? Use `/sources` to manage streams interactively.

## Coming Soon

- **Spotify Integration** — Connect your Spotify account to play your own playlists and liked songs directly through the plugin
- **`/surprise`** — Plays a random genre or station you've never listened to before — perfect for discovering new music
- **Auto-Vibe Mode** — The DJ continuously monitors your session and switches genres automatically as your work changes, no commands needed
- **More Stations** — Expanded and better curated station library with more genres and sources from around the world

