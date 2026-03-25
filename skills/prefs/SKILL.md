---
name: prefs
description: Show your saved claude-music preferences and favorite stations
disable-model-invocation: true
---

# Preferences

Show the user what claude-music knows about their preferences.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" load-prefs
```

Then read the sources file to resolve station URLs to names:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/sources.yml"
```

Display in a friendly format:

**♪ Your preferences ♪**

- **Genre:** lofi
- **Volume:** 50/100
- **Favorite stations:**
  - lofi — Nightwave Plaza
  - jazz — SomaFM Fluid

Match the URLs in `favorite_stations` to the station `name` in sources.yml. Only show genres that have a favorite. If no favorites yet, say "None yet — the more you listen, the more I learn."

Don't show the `autoplay` or `player` fields — those are internal.
