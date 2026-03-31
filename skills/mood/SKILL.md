---
name: mood
description: "Mood — tell the DJ how you're feeling and it picks the right music"
model: haiku
allowed-tools: Bash
---

This skill is part of the claude-music plugin. Only invoke when the user explicitly uses the slash command.

# Mood

The user describes their mood, feeling, or what kind of music they want in their own words. The DJ interprets it and picks the best genre.

## Instructions

The user said: "$ARGUMENTS"

Based on this, pick the best genre and station, then play it immediately. Do NOT spawn an agent or delegate.

### Step 1: Read genres and match mood

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
"
```

Using the tags and descriptions, match the user's mood to the best genre.

### Step 2: Play it

Pick a specific station name from the matched genre, then:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/music-controller.sh" play "<station name>"
```

### Step 3: Respond

Return a message in EXACTLY this format:

**♪ Now playing {genre} — {station name}. {one-liner reason tied to the mood} ♪**

- If `takeover` is `true` in the JSON output: prefix with *Switched over from another session —*
- If error about no audio player: run the `install_command` (if `has_sudo` is true) or `nosudo_hint` (if false) from the JSON, then retry play automatically.

Keep it to one line. Do not explain your reasoning.
