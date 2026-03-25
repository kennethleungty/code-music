# Installing code-music for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add code-music to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["code-music@git+https://github.com/kennethleungty/code-music.git"]
}
```

Restart OpenCode. That's it — the plugin auto-installs and registers all skills.

Verify by running: `/play`

## Requirements

- An audio player: **mpv** (recommended) or **ffplay**
- The plugin auto-detects your platform and walks you through installing one if needed

## Updating

code-music updates automatically when you restart OpenCode.

To pin a specific version:

```json
{
  "plugin": ["code-music@git+https://github.com/kennethleungty/code-music.git#v1.0.3"]
}
```

## Troubleshooting

### Plugin not loading

1. Verify the plugin line in your `opencode.json`
2. Make sure you're running a recent version of OpenCode
3. Restart OpenCode after making changes

### No audio

1. Check that mpv or ffplay is installed: `which mpv` or `which ffplay`
2. The plugin will offer to install one for you on first `/play`

## Getting Help

- Report issues: https://github.com/kennethleungty/code-music/issues
- Full documentation: https://github.com/kennethleungty/code-music#readme
