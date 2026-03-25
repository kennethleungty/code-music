---
name: say
description: Tell the DJ your mood or vibe in your own words and it picks the right music
model: sonnet
allowed-tools: Bash, Agent
---

# Say

The user describes their mood, feeling, or what kind of music they want in their own words. The DJ interprets it and picks the best genre.

## Instructions

Pass the user's input to the `dj` agent:

> The user said: "$ARGUMENTS"
> Based on this, pick the best genre and play it. Use the music controller to start playback.
