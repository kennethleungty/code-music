# code-music for Codex

Background music for your Codex coding sessions. Lofi, jazz, classical, ambient, electronic — streaming live from the internet.

## Installation

### Personal install

1. Clone the plugin:

```bash
git clone https://github.com/kennethleungty/code-music.git ~/.codex/plugins/code-music
```

2. Add to your personal marketplace at `~/.agents/plugins/marketplace.json`:

```json
{
  "name": "code-music-local",
  "interface": {
    "displayName": "Code Music Local"
  },
  "plugins": [
    {
      "name": "code-music",
      "source": {
        "source": "local",
        "path": "./~/.codex/plugins/code-music"
      },
      "category": "Productivity"
    }
  ]
}
```

3. Restart Codex.

### Repo-scoped install

1. Clone the plugin into your repo:

```bash
git clone https://github.com/kennethleungty/code-music.git plugins/code-music
```

2. Add to `$REPO_ROOT/.agents/plugins/marketplace.json`:

```json
{
  "name": "code-music-repo",
  "interface": {
    "displayName": "Code Music Repo"
  },
  "plugins": [
    {
      "name": "code-music",
      "source": {
        "source": "local",
        "path": "./plugins/code-music"
      },
      "category": "Productivity"
    }
  ]
}
```

3. Restart Codex.

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
| `/mood <feeling>` | Tell the DJ how you're feeling and it picks the right music |
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

See the full [README](https://github.com/kennethleungty/code-music#readme) for more details.
