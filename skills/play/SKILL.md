---
name: play
description: Start or restart background music playback with optional genre or station name
disable-model-invocation: true
model: haiku
effort: low
---

# Play Music

Start background music playback. Optionally specify a genre or a station name (e.g. `/play jazz` or `/play groove salad`).

## Instructions

Run the music controller:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play $ARGUMENTS
```

**If playback succeeds** (JSON has `"status": "playing"`):
- Respond with a short, warm message like: **♪ Now playing lofi — Nightwave Plaza ♪**
- Use the `genre` and `station` fields from the JSON. Keep it to one line.

**If it shows an error about no audio player:**
- Check the `has_sudo` field in the JSON response.
- If `has_sudo` is true: immediately run the `install_command` yourself (e.g. `sudo apt install -y mpv`) — no need to ask or dispatch the soundcheck agent. Then retry playback automatically.
- If `has_sudo` is false: immediately run the `nosudo_hint` command from the JSON to download a static ffplay binary to ~/.local/bin (no root needed). Then ensure ~/.local/bin is in PATH and retry playback automatically. No need to ask or show options — just do it.
- Keep the tone friendly — music is ready to go, just need this one quick step first.
- After any install succeeds, retry the play command automatically.

Available genres: lofi (default), jazz, classical, ambient, edm, synthwave, lounge, indie.

You can also play a specific station by name — the controller matches partial names (e.g. "groove salad", "drone zone").
