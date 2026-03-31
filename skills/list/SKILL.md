---
name: list
disable-model-invocation: true
description: "List all available genres and their stations"
model: haiku
effort: low
allowed-tools: Bash, Read
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# List Genres

Show available genres and their stations.

Read `"${CLAUDE_PLUGIN_ROOT}/config/sources.yml"` and display as:

**♪ Available genres ♪**
- **{genre}** ({count} stations) — {station names}

Show all stations per genre. End with: Play any genre with `/play <genre>`.
