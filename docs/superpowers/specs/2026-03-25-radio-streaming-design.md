# Radio Streaming Server — Design Spec

**Date:** 2026-03-25
**Approach:** Icecast 2 + Liquidsoap (Dockerized) with Next.js web frontend
**Scale:** Community radio, 10-100 concurrent listeners, 5+ channels

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│  MP3 Files  │────→│  Liquidsoap  │────→│   Icecast 2  │──→ Listeners
│ (per channel)     │  (single      │     │  (broadcast)  │
└─────────────┘     │   instance)   │     └──────┬───────┘
                    └──────────────┘            │
                                          JSON status API
                                                │
                                         ┌──────┴───────┐
                                         │   Web App    │
                                         │  (Next.js)   │
                                         └──────────────┘
```

**Three layers:**

1. **Liquidsoap** — a single instance handling all channels. Each channel is a separate `playlist()` source with its own `output.icecast()` block within one Liquidsoap script. This is the standard pattern — one process, multiple outputs — and avoids the overhead of running separate containers per channel.
2. **Icecast 2** — receives streams from Liquidsoap, serves them to listeners via HTTP, exposes JSON stats at `/status-json.xsl`. Verify the JSON endpoint works with the specific Docker image chosen (some builds require compile-time flags).
3. **Next.js web app** — SomaFM-inspired frontend that polls Icecast stats for now-playing info, listener counts, and channel metadata.

All three run as Docker containers via `docker-compose` on a shared bridge network. Services reference each other by container name (e.g., Liquidsoap connects to `icecast:8000`, Next.js polls `icecast:8000/status-json.xsl`). Only Icecast and Nginx expose ports to the host.

---

## Music Library & Hot Reload

### Repo folder structure

```
music/
  channels/
    lofi/
      track1.mp3
      track2.mp3
    classical/
      piece1.mp3
    jazz/
    ambient/
    electronic/
  fallback/
    fallback.mp3        # Ships with the repo, plays when a channel has no tracks
```

- Each subfolder under `music/channels/` represents a channel.
- Drop MP3 files into a channel folder to add them to that channel's playlist.
- MP3s are `.gitignore`'d (too large for git). The repo holds the folder structure and config only.
- A default `fallback.mp3` ships with the repo (short royalty-free loop) to prevent dead air on empty channels or first deploy.
- **Bitrate convention:** All source MP3s should be CBR 128kbps to match the output stream bitrate. Mismatched bitrates (e.g., 320kbps or VBR files) force Liquidsoap to transcode on the fly, increasing CPU usage significantly.

### Hot reload behavior

- Liquidsoap uses `playlist()` with `reload_mode="seconds"` and a short interval (e.g., 10 seconds). This causes Liquidsoap to periodically re-scan the playlist directory for new/removed files. There is no filesystem watch mode in Liquidsoap.
- New or removed MP3s are picked up within the reload interval, taking effect on the next track transition.
- For immediate reload, a script (`scripts/reload-channels.sh`) sends a reload command to Liquidsoap via its telnet/socket interface.
- **New channel folders** require updating the Liquidsoap script (adding a new `playlist()` + `output.icecast()` block) and restarting the container.

### Channel config generation

A startup script scans `music/channels/` directories and generates the Liquidsoap configuration. Each directory name maps to:
- A `playlist()` source pointing to that directory
- An `output.icecast()` block with mount point `/<channel-name>`
- Channel metadata (name, description, artwork) defined in an optional `channel.json` file within each channel folder

### Deployment of music files

- `rsync` or `scp` music files to the server.
- Alternatively, use `aws s3 sync` to download from S3 to local disk. **Do not use S3 FUSE mounts** (s3fs/goofys) — they are unreliable for continuous audio streaming due to high latency and caching issues.
- The channel folder names are the source of truth for config generation.

---

## Exposed Stream URLs (Public API)

A core design goal — inspired by SomaFM — is that every channel is accessible as a **plain HTTP stream URL** that any external application can consume directly:

```
http://your-server:8000/lofi
http://your-server:8000/jazz
http://your-server:8000/classical
http://your-server:8000/ambient
http://your-server:8000/electronic
```

### How it works

- Icecast serves each channel as an HTTP mount point. A listener connects with a simple GET request and receives a never-ending stream of MP3 bytes.
- **No authentication required** on the listener side — streams are intentionally public, just like SomaFM.
- Any HTTP-capable client can consume the stream: `mpv`, VLC, `ffplay`, `curl`, mobile apps, browser `<audio>` tags, or other applications.
- Metadata (current track title, artist) is embedded in the stream via ICY protocol headers, so compatible players display "Now Playing" info automatically.

### Use cases

- **External players:** Users paste the stream URL into any media player.
- **Third-party apps:** Other projects (e.g., the `claude-music` plugin) can add these URLs to their stream lists.
- **Embeds:** The stream URL can be embedded in any webpage via an HTML5 `<audio>` element.
- **API consumers:** The Icecast `/status-json.xsl` endpoint provides machine-readable JSON with all mount points, current tracks, and listener counts — a lightweight read-only API.

### Stream discovery

The web app's channel detail page prominently displays the direct stream URL with copy-to-clipboard functionality, making it easy for listeners to use their preferred player.

---

## Channels

- Each channel = one `playlist()` + `output.icecast()` block within a single Liquidsoap instance, feeding one Icecast mount point (e.g., `/lofi`, `/jazz`).
- All mount points served by a single Icecast instance.
- Adding a new channel: create the folder under `music/channels/`, add a `channel.json` with metadata, re-run config generation, restart Liquidsoap container.
- Starting with 5+ channels; config-driven, not code changes.

---

## Web App (SomaFM-inspired)

### Included

- **Landing page** — all channels displayed as cards (artwork, genre label, current track, listener count).
- **Channel detail page** — HTML5 audio player, track history (last 10 tracks), channel description, stream URL for external players.
- **Now Playing bar** — persistent bottom bar across all pages showing current track and playback controls.
- **Responsive design** — mobile-friendly layout.
- **Listener count badges** — pulled from Icecast JSON stats.

### Not included

- No user accounts or login.
- No donation/payment system.
- No song request or voting.
- No live DJ/talk show scheduling.
- No chat.

### Tech stack

- **Next.js** (React) with **Tailwind CSS**.
- Server-side polling of Icecast's `/status-json.xsl` endpoint every 10 seconds for current state.
- Track history stored in a lightweight **SQLite** database on a Docker volume mount (see Track History section below).

---

## Track History

Polling Icecast's status endpoint can miss short tracks or rapid transitions. Instead, track history is captured at the source:

- **Liquidsoap `on_track` callback** fires every time a new track starts on any channel. This callback writes a record (channel, title, artist, timestamp) to a shared JSON log file or directly to the SQLite database via a small HTTP endpoint on the Next.js app.
- The Next.js app reads from SQLite to display the last 10 tracks per channel.
- **SQLite constraints:** The database file lives on a Docker named volume (`data-volume:/data/tracks.db`) to survive container restarts. SQLite's single-writer model is fine at this scale (one Liquidsoap instance writing, one Next.js instance reading). If the web app ever scales to multiple containers, migrate to PostgreSQL.
- **Cleanup:** A cron job or application-level pruning removes entries older than 7 days to prevent unbounded growth.

---

## Handling Complexities

### Scaling (10-100+ listeners)

- Icecast handles hundreds of concurrent connections on a single instance.
- If growth exceeds one server, Icecast supports **relay servers** — a second Icecast instance mirrors the first and shares the listener load.
- At community scale, a single 2-vCPU VM handles everything comfortably.

### Metadata & Now Playing

- Liquidsoap reads ID3 tags from MP3 files and pushes metadata to Icecast with each track change.
- Icecast exposes current metadata via `/status-json.xsl` (track title, listener count per mount).
- Web app polls this every 10 seconds for live display.
- Track history captured via Liquidsoap `on_track` callback (see Track History section).

### Crossfading & Dead Air

- Liquidsoap handles crossfade between tracks (configurable, default 3 seconds).
- Each channel uses a `fallback()` chain: primary playlist source, then a fallback track (`music/fallback/fallback.mp3`).
- `strip_blank()` wraps the primary source — when silence is detected, it marks the source as unavailable, causing the `fallback()` operator to switch to the fallback track. This prevents dead air but does not "skip" tracks directly.
- When the primary source recovers (next non-silent track), `fallback()` switches back automatically.

### Reliability & Restarts

- Docker `restart: always` policy keeps services running.
- Liquidsoap reconnects to Icecast automatically if connection drops.
- Health checks in `docker-compose.yml` monitor Icecast HTTP endpoint.

---

## Hosting & Cost Estimates (AWS)

### Bandwidth calculation

100 concurrent listeners x 128 kbps = 12,800 kbps = 1,600 KB/s.

| Scenario | Daily | Monthly |
|----------|-------|---------|
| 12 hours/day | ~69 GB | ~2.0 TB |
| 24 hours/day | ~138 GB | ~4.1 TB |

### Cost comparison

| Option | VM | Bandwidth Included | Overage | Estimated Total |
|--------|----|--------------------|---------|-----------------|
| **AWS Lightsail $20/mo** (recommended) | 2 vCPU, 4GB RAM | 4 TB | $0.09/GB | **$20-40/mo** |
| **AWS EC2 t3.medium** | 2 vCPU, 4GB RAM | 100 GB free | $0.09/GB | **$180-400/mo** |
| **Hetzner VPS** (cheapest) | 2 vCPU, 4GB RAM | 20 TB | included | **$5-10/mo** |

### Cost notes

- **Bandwidth is the dominant cost.** EC2 is prohibitively expensive for streaming at this scale due to egress pricing. Avoid it.
- **Recommended:** AWS Lightsail at **$20/mo**. The 4 TB transfer cap covers ~100 listeners at 12 hr/day. Monitor usage — if you approach the cap, either upgrade to the $40 tier (5 TB) or switch to Hetzner.
- **Budget option:** Hetzner VPS at **$5-10/mo** with 20 TB included transfer. Best cost-to-bandwidth ratio by far.

| Additional costs | Estimate |
|-----------------|----------|
| Domain name (Route 53 or any registrar) | ~$1/mo |
| SSL certificate (Let's Encrypt) | $0 |
| **Realistic total (Lightsail)** | **$20-40/mo** |
| **Realistic total (Hetzner)** | **$5-10/mo** |

---

## Network & TLS Architecture

```
Internet → [Nginx :443 (TLS)] → Web App :3000
                               → Icecast :8000 (proxied at /stream/*)
         → [Icecast :8000 direct] → Audio streams (no TLS)
```

### Design decision: Dual access for audio streams

- **Web app** is served exclusively over HTTPS via Nginx (port 443).
- **Audio streams** are available two ways:
  - Via Nginx HTTPS proxy at `https://your-domain/stream/lofi` (for browsers and modern clients).
  - Via direct Icecast HTTP at `http://your-domain:8000/lofi` (for legacy players that don't support HTTPS streams — this is common).
- Port 8000 is intentionally left open in the firewall for direct stream access. This is the standard approach for internet radio (SomaFM does the same).
- The Icecast admin panel is bound to localhost only and accessed via SSH tunnel — it is NOT exposed through Nginx or port 8000.

---

## Security Considerations

| Risk | Mitigation |
|------|-----------|
| **Icecast admin panel exposed** | Bind admin to localhost only; access via SSH tunnel. Change default passwords. |
| **Liquidsoap source auth** | Use strong source passwords in Icecast config; never use defaults ("hackme"). |
| **DDoS on web app** | Cloudflare proxy for the web app (port 443). Cloudflare's free plan covers standard HTTP/HTTPS traffic. |
| **DDoS on audio streams** | Cloudflare **cannot** proxy audio streams (ToS prohibits streaming media on free/pro plans). Mitigate with: Icecast `<limits>` block (max connections per IP), iptables rate limiting, and the Lightsail firewall. At community scale, this is sufficient. |
| **Bandwidth abuse** | Icecast `<limits>` config: cap total listeners and per-IP connections. Monitor via Icecast stats. |
| **Unauthorized stream injection** | Icecast requires source authentication; only the Liquidsoap instance with credentials can push audio. |
| **MP3 file uploads** | No public upload mechanism. Files managed via SSH/SCP only. |
| **Web app vulnerabilities** | Standard Next.js security (CSP headers, no user input to DB). No auth = no credential theft risk. |
| **SSL/TLS** | Let's Encrypt for HTTPS on web app via Nginx. Audio streams optionally proxied through Nginx for HTTPS, with fallback direct HTTP access on port 8000. |
| **Server hardening** | UFW firewall (allow 80, 443, 8000). SSH key-only auth. Fail2ban. Unattended upgrades. |
| **Copyright/licensing** | Only stream music you have rights to. Use Creative Commons / royalty-free libraries. Display licensing info on the site. |

---

## Monitoring & Logging

| Concern | Approach |
|---------|----------|
| **Log aggregation** | Docker log driver set to `json-file` with max-size rotation. Logs accessible via `docker logs`. For more, add Loki or ship to CloudWatch. |
| **Icecast health** | Health check polls `/status-json.xsl` every 30s. Alert if unresponsive. |
| **Channel health** | Monitor listener count per mount — a channel with 0 listeners for an extended period while others have listeners may indicate a crashed Liquidsoap output. |
| **Disk usage** | Monitor via cron + alert. MP3 library + SQLite + logs. Set alert threshold at 80% disk. |
| **Bandwidth tracking** | Icecast stats show total bytes served. Lightsail dashboard shows transfer usage against cap. |
| **Uptime** | External ping monitor (e.g., UptimeRobot free tier) on the web app and one stream URL. |

---

## Workplan

| Phase | What | Effort |
|-------|------|--------|
| **1. Infrastructure** | Provision Lightsail VM, domain, install Docker, configure UFW | ~1 day |
| **2. Icecast + Liquidsoap** | Configure Icecast server, single Liquidsoap script with multiple channel outputs, test streaming with one channel | ~2 days |
| **3. Music library** | Set up `music/channels/` folder structure, config generation script, organize MP3s (CBR 128kbps), add fallback track, ensure proper ID3 tags | ~1 day |
| **4. Web app** | Next.js app with channel listing, persistent audio player, now-playing bar, track history, responsive design | ~4-5 days |
| **5. Track history** | Liquidsoap `on_track` callback, SQLite on Docker volume, history API endpoint, cleanup job | ~1 day |
| **6. Integration** | Connect web app to Icecast stats, end-to-end testing across channels | ~1-2 days |
| **7. Nginx + TLS** | Nginx reverse proxy, Let's Encrypt, dual-access stream config (HTTPS + direct HTTP) | ~1 day |
| **8. Security & hardening** | Icecast auth lockdown, firewall rules, Fail2ban, admin panel lockdown | ~0.5 day |
| **9. Monitoring** | Health checks, log rotation, UptimeRobot, bandwidth alerts | ~0.5 day |
| **10. Deploy & go-live** | Docker Compose production config, smoke test all channels, document runbook | ~1 day |
| | **Total estimate** | **~13-16 days** |
