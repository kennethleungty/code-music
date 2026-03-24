# YAML Music Sources Config + Vibe Command

**Date:** 2026-03-25
**Status:** Approved

## Summary

Two changes:

1. Replace `scripts/streams.json` and the `{genre}-fallback.mp3` naming convention with a single `config/stations.yml` file. Each genre has explicit `streams` and `files` sections, making it easy to browse, expand, and modify music sources.
2. Add `/claude-music:vibe` command — user describes their mood or what they need, and the DJ agent picks the right genre.

## Config format

File: `config/stations.yml`

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

### Structure rules

- Top-level keys are genre names. Adding a genre = adding a new key.
- Each genre has `streams` (list of `{name, url}`) and `files` (list of `{name, path}`).
- Either section can be empty (`[]`) or omitted entirely.
- File paths are relative to `music/` in the plugin root. Absolute paths also work.

## Playback priority

1. Pick a random stream from the genre's `streams` list.
2. Check if reachable (existing curl check).
3. If unreachable (or no streams defined), pick a random file from `files`.
4. Error if both are empty/unavailable.

## YAML parsing

The controller is bash. Use Python3 to parse YAML:

- Primary: `python3 -c "import yaml; ..."` (PyYAML)
- Fallback: `python3 -c "import json, re; ..."` with a minimal regex-based YAML subset parser for the simple structure we use (no anchors, no complex types)

Python3 is already a soft dependency in the controller.

## `/claude-music:vibe` command

A new slash command that lets users describe their mood in natural language:

```
/claude-music:vibe i'm feeling tired, need something energetic
/claude-music:vibe deep focus session, lots of reading
/claude-music:vibe chill vibes, winding down for the day
```

### How it works

1. New skill file `skills/vibe.md` — receives the user's text as an argument
2. The skill dispatches the existing `dj` agent, passing the user's mood text as context
3. The DJ agent maps the mood to a genre (using its existing activity→genre table) and calls `music-controller.sh play <genre>`
4. DJ agent returns a short one-liner like: "Switching to jazz — energy boost incoming"

### Updates to DJ agent

`agents/dj.md` needs a small addition to its prompt: in addition to reading coding activity context, it should also handle direct mood/feeling descriptions from the user. The existing genre mapping table covers most moods already (e.g., "tired + energetic" → jazz, "deep focus" → classical, "chill" → lofi).

## Changes required

1. **New file** `config/stations.yml` — all streams migrated from `streams.json`
2. **Update `scripts/music-controller.sh`**:
   - Point `STREAMS_FILE` to `config/stations.yml`
   - Rewrite `get_stream_url()` to parse YAML via Python3
   - Rewrite `get_fallback_file()` to read `files` from YAML instead of scanning directory
3. **Delete** `scripts/streams.json`
4. **Update `README.md`** — "Offline Mode" section references YAML config instead of naming convention
5. **New file** `skills/vibe.md` — slash command skill that takes mood text and dispatches the DJ agent
6. **Update `agents/dj.md`** — add mood/feeling interpretation alongside existing coding-activity matching
7. **Update `README.md`** — add `/claude-music:vibe` to the controls table
