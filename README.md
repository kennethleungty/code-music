# claude-music

Background music for your Claude Code sessions — lofi, jazz, classical, ambient and more.

Music starts automatically when you open a Claude Code session and stops when you close it. A DJ agent picks the right genre based on what you're working on.

## Installation

### Requirements

You need a command-line audio player. **mpv** is recommended:

```bash
# macOS
brew install mpv

# Ubuntu/Debian
sudo apt install mpv

# Arch
sudo pacman -S mpv
```

Other supported players (auto-detected): `ffplay` (FFmpeg), `afplay` (macOS built-in), `play` (SoX).

### Install the Plugin

```bash
# From the official marketplace (when available)
/plugin install claude-music

# Or load locally for development
claude --plugin-dir /path/to/claude-music
```

## Features

### Auto-Play on Session Start

Music starts playing automatically when you open a Claude Code session. Set `autoplay` to `false` in preferences to disable.

### DJ Agent

The DJ agent analyzes what you're working on and picks the right genre:

- **Debugging** → lofi (calm focus)
- **New features** → jazz (energized flow)
- **Code review** → classical (contemplative)
- **Brainstorming** → ambient (creative space)

Claude invokes the DJ automatically when your work context shifts, or you can ask: "ask the DJ to pick something."

### Now Playing

Use `/music:music-status` to see what's currently playing, including track metadata when available (mpv with socat required for metadata).

## Commands

| Command | Description |
|---------|-------------|
| `/music:play [genre]` | Start playback (default: your preferred genre) |
| `/music:stop` | Stop playback |
| `/music:pause` | Pause playback |
| `/music:resume` | Resume paused playback |
| `/music:next` | Skip to a different station in the same genre |
| `/music:set-genre <genre>` | Change genre and restart |
| `/music:music-status` | Show what's playing |

## Genres

| Genre | Mood | Stations |
|-------|------|----------|
| **lofi** | Chill beats, focused coding | SomaFM Groove Salad, Lush, Nightwave Plaza |
| **jazz** | Smooth, energized | SomaFM Fluid, Bossa Beyond, FIP Jazz, WDCB |
| **classical** | Deep concentration | All Classical Portland, WWFM, France Musique |
| **ambient** | Creative, spacious | SomaFM Drone Zone, Deep Space One, Space Station |

## Configuration

Preferences are stored in `${CLAUDE_PLUGIN_DATA}/preferences.json` and persist across sessions:

```json
{
  "genre": "lofi",
  "volume": "70",
  "autoplay": "true",
  "player": "auto"
}
```

- **genre**: Default genre (lofi, jazz, classical, ambient)
- **volume**: 0-100
- **autoplay**: Start music automatically on session start
- **player**: Audio player (auto, mpv, ffplay, afplay, play)

## Offline Fallback

Place MP3 files in the `music/` directory as offline fallbacks. Name them `<genre>-fallback.mp3` (e.g., `lofi-fallback.mp3`). When streams are unavailable, the plugin plays these files on loop.

## How It Works

1. **SessionStart hook** detects your audio player, loads preferences, and auto-plays music
2. **Skills** provide slash commands that call `scripts/music-controller.sh`
3. **music-controller.sh** is the single source of truth for all audio operations
4. **SessionEnd hook** stops playback when you close the session
5. **DJ agent** (haiku model) reads your coding context and picks the right genre

## License

MIT
