# Music for Claude Code

Background music that plays while you code. Lofi, jazz, classical, ambient, EDM — streaming live from SomaFM and public radio, right in your terminal.

No setup, no accounts, no ads. Just install and play.

## Installation

### Claude Code (Official Marketplace)

```
/plugin install claude-music
```

That's it. Start playing with:

```
/play
```

> Don't have an audio player installed? No worries — the plugin detects this and walks you through installing one automatically.

### Manual (local development)

```bash
git clone https://github.com/kennethleungty/claude-music.git
claude --plugin-dir ./claude-music
```

## Quick Start

```
/play                # Start playing (lofi by default)
/play jazz           # Play a specific genre
/stop                # Stop the music
```

Or let the AI DJ pick for you:

```
/vibe                            # DJ reads your session and picks automatically
/say feeling tired, need energy  # Tell the DJ your mood in your own words
```

## All Commands

| Command | What it does |
|---------|-------------|
| `/play [genre]` | Start playing music (lofi by default) |
| `/stop` | Stop the music and show session stats |
| `/next` | Switch to a different station (same genre) |
| `/vibe` | AI DJ reads your session and picks the best genre |
| `/dj` | Same as `/vibe` |
| `/say <mood>` | Tell the DJ your mood and it picks the right music |
| `/focus [min] [genre]` | Pomodoro timer with music (default 25 min) |
| `/pomodoro` | Same as `/focus` |
| `/volume [0-100]` | Set volume, or show current if no number given |
| `/status` | See what's playing right now |
| `/list` | List available genres |
| `/sources` | View, add, edit, or remove streams |
| `/help` | Show help |

## Genres

| Genre | Vibe | Great for | Stations |
|-------|------|-----------|----------|
| **lofi** | Chill downtempo beats, mellow vibes | Focused coding, debugging, writing tests | 3 |
| **jazz** | Smooth jazz, bossa nova, instrumental | Building features, refactoring | 4 |
| **classical** | Orchestral, chamber music, deep focus | Code review, reading, research | 4 |
| **ambient** | Atmospheric drones, space music, minimal beats | Brainstorming, design, creative work | 7 |
| **edm** | Electronic, IDM, dub, secret agent grooves | Shipping sprints, high-energy sessions | 6 |

Each genre has multiple radio stations. Use `/next` to cycle through them.

## Your AI DJ

The plugin includes a DJ agent that picks the right music for you. Two ways to use it:

- **`/vibe`** — The DJ reads your current session automatically. Debugging? It switches to lofi. Deep in a code review? Classical kicks in. No input needed, it figures it out.
- **`/say <mood>`** — Tell the DJ what you want in your own words. "feeling tired, need energy", "calm me down", "something retro and fun".

## Focus Timer

Start a pomodoro session with background music. When the timer ends, the music fades out and a chime plays.

```
/focus              # 25 min, current genre
/focus 45 ambient   # 45 min of ambient
```

## Now Playing

The status line at the bottom of your terminal shows what's currently playing — genre, station name, track title, and pomodoro countdown when active. Always visible, never scrolls away.

## Preferences

Your settings are saved automatically and persist across sessions:

- **Genre** — your preferred default
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

All streams are free, ad-free, and require no account. Primarily sourced from [SomaFM](https://somafm.com) (listener-supported internet radio since 2000) and public radio stations.

- **Lofi** — Nightwave Plaza, SomaFM Lush, SomaFM Vaporwaves
- **Jazz** — SomaFM Fluid, Bossa Beyond, FIP Jazz, WDCB Jazz
- **Classical** — All Classical Portland, WWFM, France Musique, Iowa Public Radio
- **Ambient** — SomaFM Drone Zone, Deep Space One, Space Station Soma, Mission Control, Synphaera, Dark Zone, n5MD Radio
- **EDM** — SomaFM DEF CON Radio, The Trip, Cliqhop IDM, Dub Step Beyond, Secret Agent, Illinois Street Lounge

Want to add your own stations? Use `/sources` to manage streams interactively, or edit `config/sources.yml` directly:

```yaml
lofi:
  - name: SomaFM - Groove Salad
    url: http://ice2.somafm.com/groovesalad-128-mp3
```

If a stream is unreachable, the plugin falls back to `assets/<genre>_fallback.mp3` when available.

## License

MIT
