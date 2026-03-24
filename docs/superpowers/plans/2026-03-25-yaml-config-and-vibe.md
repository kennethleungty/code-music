# YAML Stations Config + Vibe Command — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the JSON streams config with a YAML `config/stations.yml` and add a `/claude-music:vibe` command that dispatches the DJ agent based on user mood.

**Architecture:** The YAML file becomes the single source of truth for all music sources (streams + local files). The bash controller parses it via Python3. The vibe skill is a thin wrapper that passes mood text to the existing DJ agent.

**Tech Stack:** Bash, Python3 (PyYAML with fallback), YAML

**Spec:** `docs/superpowers/specs/2026-03-25-yaml-stations-config-design.md`

---

### Task 1: Create `config/stations.yml`

**Files:**
- Create: `config/stations.yml`

- [ ] **Step 1: Create the YAML config file**

Migrate all entries from `scripts/streams.json` into the new format:

```yaml
lofi:
  streams:
    - name: SomaFM - Groove Salad
      url: https://ice2.somafm.com/groovesalad-128-mp3
    - name: SomaFM - Groove Salad Classic
      url: https://ice4.somafm.com/gsclassic-128-mp3
    - name: SomaFM - Lush
      url: https://ice2.somafm.com/lush-128-mp3
    - name: Nightwave Plaza
      url: http://radio.plaza.one/mp3
  files: []

jazz:
  streams:
    - name: SomaFM - Fluid
      url: https://ice4.somafm.com/fluid-128-mp3
    - name: SomaFM - Bossa Beyond
      url: https://ice4.somafm.com/bossa-128-mp3
    - name: FIP Jazz
      url: http://direct.fipradio.fr/live/fip-webradio2.mp3
    - name: WDCB Jazz
      url: http://wdcb-ice.streamguys.org:80/wdcb128
  files: []

classical:
  streams:
    - name: All Classical Portland
      url: http://allclassical-ice.streamguys.com/ac96kmp3
    - name: WWFM The Classical Network
      url: http://wwfm.streamguys1.com/live
    - name: France Musique
      url: http://direct.francemusique.fr/live/francemusique-midfi.mp3
    - name: IPR Classical
      url: http://classical-stream.iowapublicradio.org/Classical.mp3
  files: []

ambient:
  streams:
    - name: SomaFM - Drone Zone
      url: https://ice2.somafm.com/dronezone-128-mp3
    - name: SomaFM - Deep Space One
      url: https://ice4.somafm.com/deepspaceone-128-mp3
    - name: SomaFM - Space Station Soma
      url: https://ice4.somafm.com/spacestation-128-mp3
    - name: Ambient Sleeping Pill
      url: http://radio.stereoscenic.com/asp-s
  files: []
```

- [ ] **Step 2: Commit**

```bash
git add config/stations.yml
git commit -m "feat: add YAML stations config"
```

---

### Task 2: Update `music-controller.sh` to parse YAML

**Files:**
- Modify: `scripts/music-controller.sh:15` (STREAMS_FILE path)
- Modify: `scripts/music-controller.sh:184-213` (get_stream_url)
- Modify: `scripts/music-controller.sh:215-230` (get_stream_name)
- Modify: `scripts/music-controller.sh:232-254` (get_fallback_file)
- Modify: `scripts/music-controller.sh:519-530` (do_list_genres)

- [ ] **Step 1: Update STREAMS_FILE path**

Change line 15 from:
```bash
STREAMS_FILE="$PLUGIN_ROOT/scripts/streams.json"
```
to:
```bash
STATIONS_FILE="$PLUGIN_ROOT/config/stations.yml"
```

Also rename all references from `STREAMS_FILE` to `STATIONS_FILE` throughout the file.

- [ ] **Step 2: Add a YAML query helper**

Add after the `json_set()` function (after line 48). This helper runs a Python3 snippet against the YAML file:

```bash
yaml_query() {
    local query="$1"
    if ! command -v python3 &>/dev/null; then
        echo ""
        return 1
    fi
    python3 -c "
import sys
try:
    import yaml
    with open('$STATIONS_FILE') as f:
        data = yaml.safe_load(f)
except ImportError:
    import json, re
    with open('$STATIONS_FILE') as f:
        text = f.read()
    # Minimal YAML subset parser for our simple structure
    data = {}
    current_genre = None
    current_section = None
    current_item = {}
    for line in text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        indent = len(line) - len(line.lstrip())
        if indent == 0 and stripped.endswith(':'):
            current_genre = stripped[:-1]
            data[current_genre] = {'streams': [], 'files': []}
            current_section = None
        elif indent == 2 and stripped in ('streams:', 'files:'):
            current_section = stripped[:-1]
            if current_section == 'streams' and stripped == 'streams: []':
                current_section = None
            if current_section == 'files' and stripped == 'files: []':
                current_section = None
        elif indent == 2 and stripped in ('streams: []', 'files: []'):
            pass
        elif indent == 4 and stripped.startswith('- name:'):
            if current_item and current_genre and current_section:
                data[current_genre][current_section].append(current_item)
            current_item = {'name': stripped.split(':', 1)[1].strip()}
        elif indent == 6 and stripped.startswith('url:'):
            current_item['url'] = stripped.split(':', 1)[1].strip()
            if current_item['url'].startswith('http'):
                current_item['url'] = stripped.split(': ', 1)[1].strip()
        elif indent == 6 and stripped.startswith('path:'):
            current_item['path'] = stripped.split(':', 1)[1].strip()
    if current_item and current_genre and current_section:
        data[current_genre][current_section].append(current_item)
$query
" 2>/dev/null
}
```

- [ ] **Step 3: Rewrite `get_stream_url()`**

Replace the entire function (lines 184-213):

```bash
get_stream_url() {
    local genre="${1:-lofi}"
    if [ ! -f "$STATIONS_FILE" ]; then
        echo ""
        return 1
    fi
    yaml_query "
import random
streams = data.get('$genre', {}).get('streams', [])
if streams:
    print(random.choice(streams)['url'])
else:
    sys.exit(1)
"
    return $?
}
```

- [ ] **Step 4: Rewrite `get_stream_name()`**

Replace the entire function (lines 215-230):

```bash
get_stream_name() {
    local genre="${1:-lofi}" url="$2"
    if [ ! -f "$STATIONS_FILE" ]; then
        echo "Unknown Station"
        return
    fi
    local name
    name=$(yaml_query "
for s in data.get('$genre', {}).get('streams', []):
    if s['url'] == '$url':
        print(s['name'])
        break
else:
    print('Unknown Station')
")
    echo "${name:-Unknown Station}"
}
```

- [ ] **Step 5: Rewrite `get_fallback_file()`**

Replace the entire function (lines 232-254). Now reads from the YAML `files` section instead of scanning directories:

```bash
get_fallback_file() {
    local genre="${1:-lofi}"
    if [ -f "$STATIONS_FILE" ]; then
        local file_path
        file_path=$(yaml_query "
import random
files = data.get('$genre', {}).get('files', [])
if files:
    entry = random.choice(files)
    path = entry.get('path', '')
    print(path)
else:
    sys.exit(1)
")
        if [ $? -eq 0 ] && [ -n "$file_path" ]; then
            # Resolve relative paths against MUSIC_DIR
            if [[ "$file_path" != /* ]]; then
                file_path="$MUSIC_DIR/$file_path"
            fi
            if [ -f "$file_path" ]; then
                echo "$file_path"
                return 0
            fi
        fi
    fi
    echo ""
    return 1
}
```

- [ ] **Step 6: Rewrite `do_list_genres()`**

Replace the entire function (lines 519-530):

```bash
do_list_genres() {
    if [ -f "$STATIONS_FILE" ]; then
        yaml_query "
for genre in data:
    print(genre)
"
    else
        echo "lofi"
        echo "jazz"
        echo "classical"
        echo "ambient"
    fi
}
```

- [ ] **Step 7: Verify the controller works**

Run these commands and check output:

```bash
"${PLUGIN_ROOT}/scripts/music-controller.sh" list-genres
```
Expected: lofi, jazz, classical, ambient (one per line)

- [ ] **Step 8: Commit**

```bash
git add scripts/music-controller.sh
git commit -m "feat: update music controller to parse YAML stations config"
```

---

### Task 3: Delete `scripts/streams.json`

**Files:**
- Delete: `scripts/streams.json`

- [ ] **Step 1: Remove the old JSON file**

```bash
git rm scripts/streams.json
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove old streams.json, replaced by config/stations.yml"
```

---

### Task 4: Create `/claude-music:vibe` skill

**Files:**
- Create: `skills/vibe/SKILL.md`

- [ ] **Step 1: Create the vibe skill**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add skills/vibe/SKILL.md
git commit -m "feat: add /claude-music:vibe command for mood-based genre selection"
```

---

### Task 5: Update DJ agent for mood input

**Files:**
- Modify: `agents/dj.md`

- [ ] **Step 1: Add mood interpretation to the DJ agent**

Add a new section after the "## How to Decide" table in `agents/dj.md`:

```markdown
## Mood Input

Sometimes the user describes a mood or feeling instead of a coding activity. Map it to the best genre:

| Mood / Feeling | Best Genre | Why |
|----------------|-----------|-----|
| Tired, need energy | jazz | Upbeat, energizing |
| Stressed, anxious | lofi | Calming, grounding |
| Creative, inspired | ambient | Open, expansive headspace |
| Need to focus, concentrate | classical | Deep sustained attention |
| Relaxed, chill | lofi | Matches the vibe |
| Excited, pumped up | jazz | Channels the energy |
| Sad, melancholic | classical | Contemplative, cathartic |
| Bored, restless | jazz | Stimulating change of pace |

Use your judgment for moods not in this table. Pick the genre that best serves what the user needs.
```

- [ ] **Step 2: Commit**

```bash
git add agents/dj.md
git commit -m "feat: add mood-to-genre mapping in DJ agent for vibe command"
```

---

### Task 6: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add vibe to controls table**

Add after the `/claude-music:music-status` row:

```markdown
| `/claude-music:vibe feeling tired, need energy` | Let the DJ pick music based on your mood |
```

- [ ] **Step 2: Update Offline Mode section**

Replace the current Offline Mode section with:

```markdown
## Offline Mode

No internet? Add local MP3 files to `config/stations.yml` under any genre:

\```yaml
lofi:
  streams:
    - name: SomaFM - Groove Salad
      url: https://ice2.somafm.com/groovesalad-128-mp3
  files:
    - name: My Lofi Mix
      path: lofi-chill.mp3
\```

File paths are relative to the `music/` folder inside the plugin directory. The plugin plays local files when radio streams aren't reachable.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README with vibe command and YAML config references"
```
