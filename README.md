# Music for Claude Code

Background music that plays while you code. Lofi, jazz, classical, ambient — streaming live from internet radio, right in your terminal.

Just install the plugin and music starts playing. No setup, no accounts, no ads.

## Quick Start

**1. Install the plugin**

In Claude Code:
```
/plugin install claude-music
```

**2. That's it.**

Use `/claude-music:play` to start playing. Lofi beats by default.

> Don't have an audio player installed? No worries — the plugin detects this and walks you through installing one automatically.

## Controls

Type these in Claude Code:

| Command | What it does |
|---------|-------------|
| `/claude-music:play` | Start playing music |
| `/claude-music:play jazz` | Start playing a specific genre |
| `/claude-music:stop` | Stop the music |
| `/claude-music:pause` | Pause |
| `/claude-music:resume` | Resume |
| `/claude-music:next` | Switch to a different station (same genre) |
| `/claude-music:set-genre ambient` | Change your genre |
| `/claude-music:volume 50` | Set volume (0-100) |
| `/claude-music:music-status` | See what's playing right now |
| `/claude-music:vibe feeling tired, need energy` | Let the DJ pick music based on your mood |

## Genres

| Genre | Vibe | Great for |
|-------|------|-----------|
| **lofi** | Chill beats, relaxed | Focused coding, debugging |
| **jazz** | Smooth, upbeat | Building features, writing code |
| **classical** | Deep, contemplative | Code review, reading, research |
| **ambient** | Spacious, atmospheric | Brainstorming, design, creative work |

Each genre has multiple radio stations. Use `/claude-music:next` to cycle through them.

## Your AI DJ

The plugin includes a DJ agent that reads what you're working on and picks the right music automatically. Debugging? It switches to lofi. Starting a code review? Classical kicks in.

You can also ask anytime: *"Hey, ask the DJ to pick something for this task."*

## Now Playing

The status line at the bottom of your terminal shows what's currently playing — genre, station name, and track title when available. Always visible, never scrolls away.

## Preferences

Your settings are saved automatically and persist across sessions:

- **Genre** — your preferred default (changed via `/claude-music:set-genre`)
- **Volume** — 0 to 100 (changed via `/claude-music:volume`)
- **Autoplay** — music starts automatically when a session opens (off by default)

## Works Everywhere

| Platform | How it plays |
|----------|-------------|
| **macOS** | mpv (via Homebrew) or built-in afplay |
| **Linux** | mpv (via apt, dnf, pacman, etc.) |
| **WSL2** | mpv inside WSL (with WSLg audio) or Windows-side mpv.exe |
| **Windows** | mpv (via winget, scoop, or chocolatey) |

The plugin auto-detects your platform and available audio players. If nothing is installed, it offers to set one up for you.

## Offline Mode

No internet? Add local MP3 files to `config/stations.yml` under any genre:

```yaml
lofi:
  streams:
    - name: SomaFM - Groove Salad
      url: https://ice2.somafm.com/groovesalad-128-mp3
  files:
    - name: My Lofi Mix
      path: lofi-chill.mp3
```

File paths are relative to the `music/` folder inside the plugin directory. The plugin plays local files when radio streams aren't reachable.

## Radio Stations

All streams are free, ad-free, and require no account:

- **Lofi** — SomaFM Groove Salad, Groove Salad Classic, Lush, Nightwave Plaza
- **Jazz** — SomaFM Fluid, Bossa Beyond, FIP Jazz, WDCB Jazz
- **Classical** — All Classical Portland, WWFM, France Musique, Iowa Public Radio
- **Ambient** — SomaFM Drone Zone, Deep Space One, Space Station Soma, Ambient Sleeping Pill

## License

MIT
