---
name: stop
description: Stop background music playback and show session stats
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: Bash
---

# Stop Music

Stop background music and show a colored recap card.

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" stop`.

The output contains a pre-formatted colored recap box followed by `---JSON---` and a JSON line.

- If the output contains `"already_stopped"`: just say **♪ No music playing. ♪**
- Otherwise: the colored box IS the response. Print the box lines exactly as they appear in the bash output (everything before `---JSON---`). Do NOT reformat, summarize, or wrap in a code block — output the lines verbatim so the ANSI colors render in the terminal.
