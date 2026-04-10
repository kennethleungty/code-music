---
name: dj
description: "DJ — auto-picks the best genre for your session"
model: haiku
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# DJ

Alias for `/vibe`. Auto-detect the right music based on what's happening in the current session.

## Instructions

You have the full conversation context. Pick the best music and play it in ONE step. Do NOT spawn an agent or delegate.

### Step 1: Read the room and pick music

Read the genre metadata from sources.yml:

```bash
python3 -c "
import sys
try:
    import yaml
    with open('${CLAUDE_PLUGIN_ROOT}/config/sources.yml') as f:
        data = yaml.safe_load(f)
except ImportError:
    sys.exit(1)
for genre, info in data.items():
    print(f'{genre}:')
    for s in info.get('stations', []):
        tags = ', '.join(s.get('tags', []))
        print(f'  - {s[\"name\"]}: {s.get(\"description\", \"\")}')
        print(f'    tags: {tags}')
    print()
" > /dev/null 2>&1
```

Using the tags and descriptions, match the session context to the best genre. Consider:
- What the user has been working on (e.g. debugging, building a feature, reviewing code)
- The general mood/pace of the session
- Any explicit mood signals from the user

When in doubt, lean towards relaxing genres (lofi, ambient, classical). The user prefers a chill atmosphere. Only pick high-energy genres if the session strongly suggests it.

### Step 2: Play it

Pick a specific station name from the matched genre, then:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play "<station name>"
```

### Step 3: Respond

Return a message in EXACTLY this format:

**♪ Now playing {genre} — {station name}. {one-liner reason tied to the session} ♪**

- If `takeover` is `true` in the JSON output: prefix with *Switched over from another session —*
- If error about no audio player: run the `install_command` (if `has_sudo` is true) or `nosudo_hint` (if false) from the JSON, then retry play automatically.

Keep it to one line. Do not explain your reasoning.
