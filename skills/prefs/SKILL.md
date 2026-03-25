---
name: prefs
description: Show your saved code-music preferences and favorite stations
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Preferences

Show saved preferences and favorite stations.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" full-prefs`.

**♪ Your preferences ♪** — Show Genre, Volume ({volume}/100), and Favorite stations (use `favorite_names` for resolved names, only show genres with a favorite). If no favorites: "None yet — the more you listen, the more I learn." Don't show `autoplay` or `player`.
