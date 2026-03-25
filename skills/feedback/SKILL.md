---
name: feedback
disable-model-invocation: true
description: "Feedback — report a bug or share feedback on GitHub"
model: haiku
effort: low
---

This skill is part of the code-music plugin. Only invoke when the user explicitly uses the slash command.

# Feedback

Open the GitHub issues page so the user can share feedback or report a bug.

## Instructions

1. Run this command to open the browser:

```bash
xdg-open "https://github.com/kennethleungty/code-music/issues/new" 2>/dev/null || open "https://github.com/kennethleungty/code-music/issues/new" 2>/dev/null
```

2. Tell the user:

> Opening GitHub Issues — thanks for taking the time to share feedback!
