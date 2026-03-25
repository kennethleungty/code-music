---
name: list
description: Show all available music genres and their stations
disable-model-invocation: true
model: haiku
effort: low
---

# List Genres

Show the user what genres and stations are available to play.

## Instructions

Read the sources file to get genres and stations:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/sources.yml"
```

Display the genres with their stations in a friendly format like:

**♪ Available genres ♪**

- **lofi** (5 stations) — Nightwave Plaza, SomaFM Lush, Groove Salad, ...
- **jazz** (4 stations) — SomaFM Fluid, Bossa Beyond, ...
- ...

Use the station `name` fields from the YAML. Show all stations for each genre.

End with: Play any genre with `/play <genre>`.
