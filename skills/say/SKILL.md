---
name: say
description: "Say — tell the DJ your mood and it picks the right music"
model: sonnet
allowed-tools: Bash, Agent
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Say

The user describes their mood, feeling, or what kind of music they want in their own words. The DJ interprets it and picks the best genre.

## Instructions

Pass the user's input to the `dj` agent:

> The user said: "$ARGUMENTS"
> Based on this, pick the best genre and play it. Use the music controller to start playback.
