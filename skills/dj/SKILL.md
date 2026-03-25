---
name: dj
description: Alias for /vibe — Auto-DJ reads the session context and picks the best genre automatically
---

# DJ

Alias for `/claude-music:vibe`. Auto-detect the right music based on what's happening in the current session.

## Instructions

Before invoking the DJ agent, summarize the recent session activity yourself (you already have the full conversation context). Write a 2-3 sentence summary covering:
- What the user has been working on (e.g. debugging, building a feature, reviewing code)
- The general mood/pace of the session (e.g. calm exploration, intense debugging, rapid iteration)
- Any explicit mood signals from the user (e.g. frustration, excitement, fatigue)

Then invoke the `dj` agent with your summary:

> Here's what's been happening in this session:
> [your 2-3 sentence summary]
>
> Based on this, pick the best genre and play it. Use the music controller to start playback.
>
> IMPORTANT: When in doubt, lean towards relaxing genres (lofi, ambient, classical). The user prefers a chill atmosphere. Only pick high-energy genres (edm, uptempo jazz) if the session context strongly suggests it (e.g. sprint, hacking, shipping deadline).

Do NOT pass raw conversation history to the agent. A concise summary is all it needs.
