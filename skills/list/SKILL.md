---
name: list
description: Show all available music genres
disable-model-invocation: true
---

# List Genres

Show the user what genres are available to play.

## Instructions

Run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" list-genres
```

Display the list to the user. They can play any of these with `/play <genre>`.
