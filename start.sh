#!/bin/bash
# ===========================================================================
# Container entrypoint for one DST shard. Runs on every container start and
# proceeds in four phases:
#   1. Install/update the DST dedicated server via SteamCMD (appid 343050).
#   2. Copy modoverrides.lua into the Master/ and Caves/ shard folders.
#   3. Pre-download every enabled Workshop mod with SteamCMD and unpack legacy
#      mods (their _legacy.bin ZIPs) into mods/workshop-<id>/, so the server's
#      own downloader never has to run (it times out on slow networks and also
#      wipes our copies); we therefore launch with -skip_update_server_mods.
#   4. Launch the shard named by the $SHARD_NAME env var (Master or Caves).
#
# Which shard this is comes from $SHARD_NAME, set per-service in
# docker-compose.yml. Everything else is shared between the two shards.
# `set -e` aborts the whole script if any command fails.
# ===========================================================================
set -e

DST_DIR=/home/dst/dst_server_cache                                   # where the game gets installed
STEAMCMD=/home/dst/steamcmd/steamcmd.sh                 # SteamCMD launcher (baked into image)
CLUSTER_DIR=/home/dst/.klei/DoNotStarveTogether/Cluster_1   # mounted cluster config + saves

echo "================================================"
echo "=================INSTALLING DST================="
echo "================================================"
"$STEAMCMD" \
  +force_install_dir "$DST_DIR" \
  +login anonymous \
  +app_update 343050 \
  +quit
echo "================================================"
echo "=================FINISH DST====================="
echo "================================================"

modoverrides="$CLUSTER_DIR/mods/modoverrides.lua"
if [ -f "$modoverrides" ]; then
  cp "$modoverrides" "$CLUSTER_DIR/Master/"
  cp "$modoverrides" "$CLUSTER_DIR/Caves/"
fi

echo "================================================"
echo "===============DOWNLOADING MODS================="
echo "================================================"
# Download each enabled Workshop mod with SteamCMD (no 16s timeout; it streams
# from the Steam CDN) and place every one into mods/workshop-<id>/ (V1), the only
# mod location this server setup uses:
#   * NEW-format mods  -> SteamCMD already extracted the real files; just copy.
#   * LEGACY-format    -> SteamCMD leaves a single _legacy.bin ZIP; we unzip it
#                         (the server can't read the .bin, and its own downloader
#                         times out on slow networks), so unpacking here is the
#                         only reliable way to install legacy mods.
# The server is launched with -skip_update_server_mods, so it never runs its own
# (broken here) Workshop downloader and never wipes these directories.
# 322330 = DST *client/Workshop* appid (Workshop content lives under it), not 343050.
WS_CONTENT="$DST_DIR/steamapps/workshop/content/322330"

# Parse enabled Workshop ids straight from modoverrides.lua so it stays the
# single source of truth (skip "--" comment lines like the examples).
echo "SCANNING MOD_IDS FROM $modoverrides"
mod_ids=$(grep -vE '^[[:space:]]*--' "$modoverrides" 2>/dev/null \
          | grep -oE 'workshop-[0-9]+' | grep -oE '[0-9]+' | sort -u || true)
echo "MOD_IDS = ${mod_ids//$'\n'/ }"

for id in $mod_ids; do
  # A valid V1 install requires modinfo.lua; reuse it if already present.
  if [ -f "$DST_DIR/mods/workshop-$id/modinfo.lua" ]; then
    echo ">> mods/workshop-$id already installed (has modinfo.lua), skip"
    continue
  fi
  echo ">> Downloading mod $id ..."
  "$STEAMCMD" +force_install_dir "$DST_DIR" +login anonymous \
      +workshop_download_item 322330 "$id" validate +quit
  rm -rf "$DST_DIR/mods/workshop-$id"
  if [ -f "$WS_CONTENT/$id/modinfo.lua" ]; then
    # NEW-format mod: SteamCMD already extracted the real files -> copy them.
    cp -a "$WS_CONTENT/$id" "$DST_DIR/mods/workshop-$id"
    echo ">> Installed new-format mod $id -> mods/workshop-$id"
  elif ls "$WS_CONTENT/$id"/*_legacy.bin >/dev/null 2>&1; then
    # LEGACY-format mod: SteamCMD left a single _legacy.bin ZIP. Unpack it so the
    # server finds modinfo.lua/modmain.lua (it can't read the .bin on its own).
    unzip -o -q "$WS_CONTENT/$id"/*_legacy.bin -d "$DST_DIR/mods/workshop-$id"
    echo ">> Installed legacy-format mod $id (unpacked _legacy.bin) -> mods/workshop-$id"
  else
    echo ">> ERROR: mod $id downloaded but no modinfo.lua and no _legacy.bin at $WS_CONTENT/$id"
  fi
done
echo "================================================"
echo "===============FINISH MODS======================"
echo "================================================"

echo "================================================"
echo "=================RUNNING DST===================="
echo "================================================"
if [ ! -x "$DST_DIR/bin/dontstarve_dedicated_server_nullrenderer" ]; then
  echo "ERROR: dst_server_cache binary not found at $DST_DIR/bin."
  echo "       The steamcmd install did not place files in the install dir."
  echo "       Check that $DST_DIR is writable by user dst and re-run."
  exit 1
fi
cd "$DST_DIR/bin"
# -skip_update_server_mods: start.sh already fetched + unpacked every mod above.
# The server's own downloader must NOT run: it downloads to ugc_mods/ (wiping our
# mods/workshop-<id>/ copies) and times out (result 16) on slow networks.
./dontstarve_dedicated_server_nullrenderer -shard "$SHARD_NAME" -skip_update_server_mods

