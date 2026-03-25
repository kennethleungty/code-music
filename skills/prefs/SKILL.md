---
name: prefs
description: Show your saved claude-music preferences and favorite stations
disable-model-invocation: true
model: haiku
effort: low
---

# Preferences

Show the user what claude-music knows about their preferences.

## Instructions

Run the combined command (returns prefs with station names already resolved):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" full-prefs
```

Display in a friendly format:

**♪ Your preferences ♪**

- **Genre:** {prefs.genre}
- **Volume:** {prefs.volume}/100
- **Favorite stations:**
  - lofi — {favorite_names.lofi}
  - jazz — {favorite_names.jazz}

Use `favorite_names` for resolved station names. Only show genres that have a favorite. If no favorites yet, say "None yet — the more you listen, the more I learn."

Don't show the `autoplay` or `player` fields — those are internal.
