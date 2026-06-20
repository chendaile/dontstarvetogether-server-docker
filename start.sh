#!/bin/bash
# ===========================================================================
# Container entrypoint for one DST shard. Runs on every container start and
# proceeds in four phases:
#   1. Install/update the DST dedicated server via SteamCMD (appid 343050).
#   2. Copy modoverrides.lua into the Master/ and Caves/ shard folders.
#   3. Pre-download every enabled Workshop mod with SteamCMD (see the "16s"
#      note below) so the server doesn't have to fetch them itself.
#   4. Launch the shard named by the $SHARD_NAME env var (Master or Caves).
#
# Which shard this is comes from $SHARD_NAME, set per-service in
# docker-compose.yml. Everything else is shared between the two shards.
# `set -e` aborts the whole script if any command fails.
# ===========================================================================
set -e

DST_DIR=/home/dst/DST                                   # where the game gets installed
STEAMCMD=/home/dst/steamcmd/steamcmd.sh                 # SteamCMD launcher (baked into image)
CLUSTER_DIR=/home/dst/.klei/DoNotStarveTogether/Cluster_1   # mounted cluster config + saves

echo "================================================"
echo "=================INSTALLING DST================="
echo "================================================"
"$STEAMCMD" \
  +force_install_dir "$DST_DIR" \
  +login anonymous \
  +app_update 343050 validate \
  +quit
echo "================================================"
echo "=================FINISH DST====================="
echo "================================================"

modoverrides="$DST_DIR/mods/modoverrides.lua"
if [ -f "$modoverrides" ]; then
  cp "$modoverrides" "$CLUSTER_DIR/Master/"
  cp "$modoverrides" "$CLUSTER_DIR/Caves/"
fi

# echo "================================================"
# echo "===============DOWNLOADING MODS================="
# echo "================================================"
# # Pre-download every enabled Workshop mod via SteamCMD instead of relying on the
# # dedicated server's in-game downloader, which has a short, hardcoded timeout
# # (the "16s" issue) that fails on slow/blocked networks. SteamCMD streams from
# # the Steam CDN with no such limit and resumes partial downloads. 322330 is the
# # DST *client/Workshop* appid (Workshop content lives under it), not 343050.
# WS_CONTENT="$DST_DIR/steamapps/workshop/content/322330"

# # Parse enabled Workshop ids straight from modoverrides.lua so it stays the
# # single source of truth (skip "--" comment lines like the examples).
# echo "SCANNING MOD_IDS FROM $modoverrides"
# mod_ids=$(grep -vE '^[[:space:]]*--' "$modoverrides" 2>/dev/null \
#           | grep -oE 'workshop-[0-9]+' | grep -oE '[0-9]+' | sort -u || true)
# echo "MOD_IDS = ${mod_ids//$'\n'/ }"

# for id in $mod_ids; do
#   if [ -d "$DST_DIR/mods/workshop-$id" ]; then
#     echo ">> Using existing mods/workshop-$id, skip installing it"
#     continue
#   fi
#   echo ">> Downloading mod $id ..."
#   "$STEAMCMD" +force_install_dir "$DST_DIR" +login anonymous \
#       +workshop_download_item 322330 "$id" validate +quit
#   if [ -d "$WS_CONTENT/$id" ]; then
#     rm -rf "$DST_DIR/mods/workshop-$id"
#     cp -a "$WS_CONTENT/$id" "$DST_DIR/mods/workshop-$id"
#     echo ">> Successfully downloaded mod $id to mods/workshop-$id"
#   else
#     echo ">> Mod $id failed: workshop content not found at $WS_CONTENT/$id"
#   fi
# done
# echo "================================================"
# echo "===============FINISH MODS======================"
# echo "================================================"

echo "================================================"
echo "=================RUNNING DST===================="
echo "================================================"
if [ ! -x "$DST_DIR/bin/dontstarve_dedicated_server_nullrenderer" ]; then
  echo "ERROR: DST binary not found at $DST_DIR/bin."
  echo "       The steamcmd install did not place files in the install dir."
  echo "       Check that $DST_DIR is writable by user dst and re-run."
  exit 1
fi
cd "$DST_DIR/bin"
./dontstarve_dedicated_server_nullrenderer -shard "$SHARD_NAME" 
# ./dontstarve_dedicated_server_nullrenderer -shard "$SHARD_NAME" -skip_update_server_mods

