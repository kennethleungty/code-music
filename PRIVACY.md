# Privacy Policy

**code-music** — background music for your coding sessions, right in your terminal.

Last updated: 2026-03-25

## Summary

This plugin does not collect, transmit, or store any personal data. Everything stays on your machine.

## What the plugin stores locally

The plugin saves a small amount of state to `~/.code-music/` (or `$CLAUDE_PLUGIN_DATA`) on your local filesystem:

- **preferences.json** — your chosen genre, volume level, autoplay setting, preferred audio player, and favorite stations per genre
- **state.json** — current playback state (status, genre, stream URL, player process ID, session start time, station count)
- **stats.json** — lifetime listening stats (total sessions, total minutes, genre breakdown, first/last session timestamps)
- **pomodoro.json** — active focus timer state (start time, end time, duration, status)
- **player.pid / watchdog.pid / pomodoro.pid** — process IDs for managing playback and timers
- **mpv.sock** — local Unix socket for communicating with the mpv audio player

All of these files are plain-text, stored only on your machine, and are never transmitted anywhere.

## Network requests

The plugin makes outbound network requests solely to stream audio from internet radio stations (e.g. SomaFM, public radio). These requests are standard HTTP audio streams — the same as opening the station URL in a browser.

No data is sent to these stations beyond what is required by the HTTP protocol (your IP address, user-agent from the audio player).

The plugin does not:
- Send any data to Anthropic or any third party
- Include analytics, telemetry, or tracking of any kind
- Use cookies or local storage beyond the files listed above
- Require or store any account credentials

## Data shared with Claude

During a session, the plugin injects context into Claude Code via hooks (e.g. platform info, playback status, available commands). This context is part of your local Claude Code session and is subject to [Anthropic's privacy policy](https://www.anthropic.com/privacy) and your Claude Code settings.

## Data deletion

All plugin data is stored in `~/.code-music/`. To remove it completely:

```bash
rm -rf ~/.code-music
```

Uninstalling the plugin via `/plugin uninstall code-music` removes the plugin files. The data directory may persist and can be removed manually as above.

## Changes to this policy

Updates to this policy will be reflected in this file and tracked in the repository's git history.

## Contact

For questions or concerns, open an issue at [github.com/kennethleungty/code-music](https://github.com/kennethleungty/code-music/issues).
