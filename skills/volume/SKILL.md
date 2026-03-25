---
name: volume
description: Set the music playback volume (0-100), show current volume, or adjust with up/down
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Volume

Adjust music volume (0-100), or `up`/`down` to adjust by 10.

- If `$ARGUMENTS` is empty: run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" status` → **♪ Volume: {volume}/100 ♪**
- If `up`, `down`, or a number: run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" volume-adjust $ARGUMENTS` → respond based on `direction`: **♪ Volume up/down/set to: {volume}/100 ♪**
