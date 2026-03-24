# Music for Claude Code

Background music that plays while you code. Lofi, jazz, classical, ambient — streaming live from SomaFM and public radio, right in your terminal.

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
| `/play` | Start playing music (lofi by default) |
| `/play jazz` | Play a specific genre |
| `/stop` | Stop the music |
| `/next` | Switch to a different station (same genre) |
| `/volume 50` | Set volume (0-100) |
| `/status` | See what's playing right now |
| `/vibe` | AI DJ reads your session and picks the best genre |
| `/say <mood>` | Tell the DJ your mood and it picks the right music |
| `/list` | List available genres |
| `/help` | Show help |

## Genres

| Genre | Vibe | Great for | Stations |
|-------|------|-----------|----------|
| **lofi** | Chill downtempo beats, mellow vocals | Focused coding, debugging, writing tests | 4 |
| **jazz** | Smooth jazz, bossa nova, instrumental hip-hop | Building features, refactoring | 5 |
| **classical** | Orchestral, chamber music, deep focus | Code review, reading, research | 4 |
| **ambient** | Atmospheric drones, space music, minimal beats | Brainstorming, design, creative work | 7 |

Each genre has multiple radio stations. Use `/next` to cycle through them.

## Your AI DJ

The plugin includes a DJ agent that picks the right music for you. Two ways to use it:

- **`/vibe`** — The DJ reads your current session automatically. Debugging? It switches to lofi. Deep in a code review? Classical kicks in. No input needed, it figures it out.
- **`/say <mood>`** — Tell the DJ what you want in your own words. "feeling tired, need energy", "calm me down", "something retro and fun".

## Now Playing

The status line at the bottom of your terminal shows what's currently playing — genre, station name, and track title when available. Always visible, never scrolls away.

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

- **Lofi** — SomaFM Groove Salad, Groove Salad Classic, Lush, Beat Blender
- **Jazz** — SomaFM Fluid, Bossa Beyond, Sonic Universe, FIP Jazz, WDCB Jazz
- **Classical** — All Classical Portland, WWFM, France Musique, Iowa Public Radio
- **Ambient** — SomaFM Drone Zone, Deep Space One, Space Station Soma, Mission Control, Synphaera, Dark Zone, n5MD Radio

Want to add your own stations or local files? Edit `config/sources.yml`:

```yaml
lofi:
  streams:
    - name: SomaFM - Groove Salad
      url: http://ice2.somafm.com/groovesalad-128-mp3
  files:
    - name: My Lofi Mix
      path: lofi-chill.mp3
```

File paths are relative to the `music/` folder inside the plugin directory. The plugin plays local files when radio streams aren't reachable.

## License

MIT
