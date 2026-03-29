<p align="center">
  <img src="assets/logo.png" alt="Code Music" width="350">
</p>

<h2 align="center">Music in your Claude Code Sessions</h2>

Enjoy great music and vibes while Claude Code does the heavy lifting. Lofi, jazz, classical, ambient, and more — streaming live from the internet, right in your coding session.

No setup, no sign ups, no accounts. Just install the plugin and start listening.

<!-- <p align="center">
  <img src="assets/demo.gif" alt="code-music demo" width="600">
</p> -->

## Quick Start

```
/play                # Start playing (ambient genre by default)
/play jazz           # Play a specific genre or station name
/next                # Skip to a different station (same genre)
/prev                # Go back to the previous station
/stop                # Stop the music
/volume up           # Nudge volume up (or down, or set 0-100)
/mute                # Mute without stopping the stream
/status              # See what's playing right now
```

Or let the resident AI DJ Ken pick for you:

```
/vibe                            # DJ reads your session and picks automatically
/mood feeling tired, need energy  # Tell the DJ your mood in your own words
```

Or start a focus session with a timer:

```
/focus              # 25 min pomodoro — music fades out and chimes when done
/focus 45 ambient   # 45 min with ambient music
```

See the [full command list](#all-commands) for more.

## AI DJ

The plugin includes a resident AI DJ (DJ Ken) that picks the right music for you. Debugging? He switches to lofi. Deep in a code review? Classical kicks in. He learns your preferences over time — the more you use it, the better he gets.

- **`/vibe`** — DJ Ken reads your current session and picks automatically. No input needed.
- **`/mood <feeling>`** — Tell him what you want in your own words: "calm me down", "something retro and fun".
- **`/prefs`** — See what he's learned about your taste over time.

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

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace first:

```bash
/plugin marketplace add kennethleungty/code-music-marketplace
```

Then install the plugin:

```bash
/plugin install code-music@code-music-marketplace
```

### Verify Installation

Start a new session and try `/play` or `/vibe`.

> Don't have an audio player installed? No worries — the plugin detects this and walks you through installing one automatically.

## Works Everywhere

| Platform | How it plays |
|----------|-------------|
| **macOS** | mpv (via Homebrew) or built-in afplay |
| **Linux** | mpv (via apt, dnf, pacman, etc.) |
| **WSL2** | mpv inside WSL (with WSLg audio) or Windows-side mpv.exe |
| **Windows** | mpv (via winget, scoop, or chocolatey) |

The plugin auto-detects your platform and available audio players. If nothing is installed, it offers to set one up for you.

<details>
<summary><strong>All Commands</strong></summary>

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
| `/volume [0-100 \| up \| down]` | Set volume, nudge up/down by 10, or show current |
| `/status` | See what's playing right now |
| `/list` | List available genres and their stations |
| `/stats` | See current session and lifetime listening stats |
| `/prefs` | See your saved preferences and favorite stations |
| `/reset` | Clear all preferences back to defaults |
| `/sources` | View, add, edit, or remove streams |
| `/feedback` | Report a bug or share feedback on GitHub |
| `/help` | Show help |

</details>

<details>
<summary><strong>Focus Timer</strong></summary>

Start a pomodoro session with background music. When the timer ends, the music fades out and a chime plays.

```
/focus              # 25 min, current genre
/focus 45 ambient   # 45 min of ambient
```

</details>

<details>
<summary><strong>Now Playing & Preferences</strong></summary>

The status line at the bottom of your terminal shows what's currently playing — genre, station name, track title, and pomodoro countdown when active. Always visible, never scrolls away.

Your settings are saved automatically and persist locally across sessions:

- **Genre** — your preferred default (ambient by default when fresh start)
- **Volume** — 0 to 100 (changed via `/volume`)

</details>

<details>
<summary><strong>Radio Stations</strong></summary>

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

</details>

## Coming Soon

**Spotify Integration** — Connect your Spotify account and play your own playlists directly through the plugin.
