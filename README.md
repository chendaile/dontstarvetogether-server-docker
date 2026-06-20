<p align="center">
  <a href="https://www.klei.com/games/dont-starve-together"><img src="https://img.shields.io/badge/game-Don't_Starve_Together-8B4513?style=for-the-badge" alt="DST"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/runtime-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT"></a>
</p>

<br>

<div align="center">

# 🔥 Don't Starve Together
### 🐳 Docker Dedicated Server

**Run your own world — persistent, always-on, under your control.**

`Forest + Caves` · `SteamCMD auto-install` · `Boot-time mods` · `Non-root`

<br>

<sub>📖 <a href="./README_CN.md">中文文档</a> · English</sub>

</div>

<br>

One `docker compose up`. That's all. Two containers — Master and Caves — forming one seamless world. Automatic SteamCMD installs, Workshop mods downloaded at boot, rolling game updates on restart. Nothing to wrestle with. Your server. Your rules.

---

## Why This Exists

Hosting a DST server by hand means wrestling with SteamCMD, 32-bit runtimes, mod downloads that time out, and two interdependent processes that must find each other. This project wraps all of that into a single `docker compose up` command. Clone it, drop in your config, start it. Your world is live.

---

## Quick Start

### Prerequisites

- **Docker** (24+) and **Docker Compose** (v2)
- A Linux machine with at least 4 GB RAM and 10 GB disk
- A [Klei account](https://accounts.klei.com) to generate a server token

### 1. Clone the repository

```bash
git clone <repo-url> dst-server && cd dst-server
```

### 2. Get your cluster token

1. Visit [Klei Account - Games](https://accounts.klei.com/account/game/servers?game=DontStarveTogether)
2. Enter a name, click **Generate Server Token**
3. Copy the token string
4. Paste it into `dst_config/cluster_token.txt`

### 3. Name your world

Edit `dst_config/cluster.ini` and set at minimum:

```ini
cluster_name = My World
cluster_description = Welcome!
cluster_password = yourpassword
cluster_key = any-random-string
```

> The `cluster_key` is the shared secret between Master and Caves. Generate a random string; it never leaves your host.

### 4. (Optional) Choose your mods

Edit `dst_config/mods/modoverrides.lua` — uncomment the mods you want and set `enabled=true`. Four popular quality-of-life mods are pre-configured as examples.

### 5. Start the server

```bash
docker compose up -d
```

On first boot SteamCMD downloads the DST server (~3 GB). Subsequent restarts are instant.

Your server is now listed in the DST in-game server browser.

---

## File Structure

```
.
├── Dockerfile            # Image definition (Debian + SteamCMD + 32-bit libs)
├── docker-compose.yml    # Two-container orchestration
├── start.sh              # Entrypoint: install → mods → launch
├── .env.example          # Template for port/name overrides
├── dst_config/
│   ├── cluster.ini       # Server name, password, game rules
│   ├── cluster_token.txt # Klei authentication token (gitignored)
│   ├── Master/
│   │   ├── server.ini    # Master shard network config
│   │   └── leveldataoverride.lua  # World generation settings (forest)
│   ├── Caves/
│   │   ├── server.ini    # Caves shard network config
│   │   └── leveldataoverride.lua  # World generation settings (underground)
│   └── mods/
│       └── modoverrides.lua  # Enabled mods + per-mod settings
└── dst_server_cache/     # Game binary + mod downloads (gitignored)
```

---

## Daily Operations

### Check server status

```bash
docker compose ps
docker compose logs -f --tail=50
```

### Restart after config changes

```bash
docker compose restart
```

Config files are bind-mounted — no rebuild needed.

### Update the game

```bash
docker compose down && docker compose up -d
```

`start.sh` runs SteamCMD on every boot, so a restart is an update.

### View connected players

The server logs will show join/leave events. For richer admin tools, enable the console in `cluster.ini` and use DST's built-in remote commands.

---

## Configuration Reference

| File | What it controls |
|---|---|
| `cluster.ini` | Game mode, max players, PvP, server name, password |
| `Master/server.ini` | Master port (default 11999), shard identity |
| `Caves/server.ini` | Caves port (default 11998), shard identity |
| `Master/leveldataoverride.lua` | Forest world generation (creatures, resources, seasons) |
| `Caves/leveldataoverride.lua` | Cave world generation (worms, mushrooms, nightmare cycle) |
| `mods/modoverrides.lua` | Workshop mods to enable and their settings |
| `.env` | Override container names and host ports |

### Customize .env

```bash
cp .env.example .env
```

Edit `.env` to change container names or published ports. All values have sensible defaults — delete any line you don't need.

---

## Mods

Mods are defined in `dst_config/mods/modoverrides.lua`. The syntax is:

```lua
["workshop-<mod-id>"] = {
  configuration_options = { ... },
  enabled = true
}
```

The startup script automatically downloads and installs every enabled mod at boot. No manual SteamCMD commands needed.

---

## Security Notes

- The server runs as an unprivileged user inside the container (`dst`, not `root`)
- `cluster_token.txt`, `cluster.ini`, and `adminlist.txt` are gitignored — your secrets stay local
- Expose only UDP ports 11998–11999 to the internet; the server uses no TCP

---

## Troubleshooting

| Problem | Likely fix |
|---|---|
| Server not appearing in browser | Verify `cluster_token.txt` is valid; check firewall allows UDP 11998–11999 |
| Caves not connecting to Master | Ensure `cluster_key` matches in `dst_config/cluster.ini` |
| Mods not loading | Check `docker compose logs` — mod IDs must be uncommented in `modoverrides.lua` |
| Slow first boot | Normal — SteamCMD is downloading the ~3 GB server. Wait ~5–10 minutes |

---

## License

MIT — set up your server, share the config, build on it.
