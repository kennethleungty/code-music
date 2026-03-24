# Music for Claude Code

Background music that plays while you code. Lofi, jazz, classical, ambient — streaming live from internet radio, right in your terminal.

Just install the plugin and music starts playing. No setup, no accounts, no ads.

## Quick Start

**1. Install the plugin**

In Claude Code:
```
/plugin install music
```

**2. That's it.**

Music starts automatically when your next session opens. Lofi beats by default.

> Don't have an audio player installed? No worries — the plugin detects this and walks you through installing one automatically.

## Controls

Type these in Claude Code:

| Command | What it does |
|---------|-------------|
| `/music:play` | Start playing music |
| `/music:play jazz` | Start playing a specific genre |
| `/music:stop` | Stop the music |
| `/music:pause` | Pause |
| `/music:resume` | Resume |
| `/music:next` | Switch to a different station (same genre) |
| `/music:set-genre ambient` | Change your genre |
| `/music:volume 50` | Set volume (0-100) |
| `/music:music-status` | See what's playing right now |

## Genres

| Genre | Vibe | Great for |
|-------|------|-----------|
| **lofi** | Chill beats, relaxed | Focused coding, debugging |
| **jazz** | Smooth, upbeat | Building features, writing code |
| **classical** | Deep, contemplative | Code review, reading, research |
| **ambient** | Spacious, atmospheric | Brainstorming, design, creative work |

Each genre has multiple radio stations. Use `/music:next` to cycle through them.

## Your AI DJ

The plugin includes a DJ agent that reads what you're working on and picks the right music automatically. Debugging? It switches to lofi. Starting a code review? Classical kicks in.

You can also ask anytime: *"Hey, ask the DJ to pick something for this task."*

## Now Playing

The status line at the bottom of your terminal shows what's currently playing — genre, station name, and track title when available. Always visible, never scrolls away.

## Preferences

Your settings are saved automatically and persist across sessions:

- **Genre** — your preferred default (changed via `/music:set-genre`)
- **Volume** — 0 to 100 (changed via `/music:volume`)
- **Autoplay** — music starts automatically when a session opens (on by default)

## Works Everywhere

| Platform | How it plays |
|----------|-------------|
| **macOS** | mpv (via Homebrew) or built-in afplay |
| **Linux** | mpv (via apt, dnf, pacman, etc.) |
| **WSL2** | mpv inside WSL (with WSLg audio) or Windows-side mpv.exe |
| **Windows** | mpv (via winget, scoop, or chocolatey) |

The plugin auto-detects your platform and available audio players. If nothing is installed, it offers to set one up for you.

## Offline Mode

No internet? Drop MP3 files into the `music/` folder inside the plugin directory. Name them by genre — `lofi-fallback.mp3`, `jazz-fallback.mp3`, etc. The plugin plays these on loop when radio streams aren't reachable.

## Radio Stations

All streams are free, ad-free, and require no account:

- **Lofi** — SomaFM Groove Salad, Groove Salad Classic, Lush, Nightwave Plaza
- **Jazz** — SomaFM Fluid, Bossa Beyond, FIP Jazz, WDCB Jazz
- **Classical** — All Classical Portland, WWFM, France Musique, Iowa Public Radio
- **Ambient** — SomaFM Drone Zone, Deep Space One, Space Station Soma, Ambient Sleeping Pill

## License

MIT
