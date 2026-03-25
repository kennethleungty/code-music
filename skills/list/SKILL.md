---
name: list
description: Show all available music genres and their stations
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash, Read
---

# List Genres

Show available genres and their stations.

Read `"${CLAUDE_PLUGIN_ROOT}/config/sources.yml"` and display as:

**♪ Available genres ♪**
- **{genre}** ({count} stations) — {station names}

Show all stations per genre. End with: Play any genre with `/play <genre>`.
