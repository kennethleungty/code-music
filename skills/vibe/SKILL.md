---
name: vibe
description: Pick music based on your mood — describe how you're feeling and the DJ picks the right genre
---

# Vibe

The user wants music that matches their mood. Dispatch the DJ agent to pick the right genre.

## Instructions

Pass the user's mood description to the DJ agent. The DJ will interpret the mood, pick the best genre, and start playback.

User's mood: $ARGUMENTS

Invoke the `dj` agent with this context:

> The user described their mood: "$ARGUMENTS"
> Based on this mood, pick the best genre and play it. Use the music controller to start playback.
