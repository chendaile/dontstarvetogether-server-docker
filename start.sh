#!/bin/bash
# ===========================================================================
# Container entrypoint for one DST shard. Runs on every container start and
# proceeds in four phases / 容器入口脚本，每次启动时运行，分四个阶段执行：
#   1. Install/update the DST dedicated server via SteamCMD (appid 343050).
#      通过 SteamCMD 安装/更新 DST 专用服务端 (appid 343050)
#   2. Copy modoverrides.lua into the Master/ and Caves/ shard folders.
#      将 modoverrides.lua 复制到 Master/ 和 Caves/ 分片目录
#   3. Pre-download every enabled Workshop mod with SteamCMD and unpack legacy
#      mods (their _legacy.bin ZIPs) into mods/workshop-<id>/, so the server's
#      own downloader never has to run (it times out on slow networks and also
#      wipes our copies); we therefore launch with -skip_update_server_mods.
#      预下载所有启用的工坊 mod 并将旧版 mod 的 _legacy.bin 压缩包解压到
#      mods/workshop-<id>/，使服务端自带下载器无需运行（慢速网络下会超时
#      且覆盖已有文件），因此以 -skip_update_server_mods 启动。
#   4. Launch the shard named by $SHARD_NAME (Master or Caves).
#      启动 $SHARD_NAME 指定的分片（Master 或 Caves）
#
# Which shard this is comes from $SHARD_NAME, set per-service in
# docker-compose.yml. Everything else is shared between the two shards.
# 分片类型由 docker-compose.yml 中按服务设置的 $SHARD_NAME 决定，
# 其余配置在两个分片间共享。
# `set -e` aborts the whole script if any command fails.
# `set -e` 确保任意命令失败时立即中止脚本。
# ===========================================================================
set -e

DST_DIR=/home/dst/dst_server_cache                                   # game install dir / 游戏安装目录
STEAMCMD=/home/dst/steamcmd/steamcmd.sh                              # SteamCMD launcher (baked into image) / SteamCMD 启动器 (内置镜像)
CLUSTER_DIR=/home/dst/.klei/DoNotStarveTogether/Cluster_1            # mounted cluster config + saves / 挂载的集群配置和存档

echo "================================================"
echo "============= INSTALLING DST ==================="
echo "============= 正在安装 DST ====================="
echo "================================================"
"$STEAMCMD" \
  +force_install_dir "$DST_DIR" \
  +login anonymous \
  +app_update 343050 \
  +quit
echo "================================================"
echo "============= DST INSTALL DONE ================="
echo "============= DST 安装完成 ====================="
echo "================================================"

modoverrides="$CLUSTER_DIR/mods/modoverrides.lua"
if [ -f "$modoverrides" ]; then
  cp "$modoverrides" "$CLUSTER_DIR/Master/"
  cp "$modoverrides" "$CLUSTER_DIR/Caves/"
fi

echo "================================================"
echo "============= DOWNLOADING MODS ================="
echo "============= 正在下载 MOD ====================="
echo "================================================"
# Download each enabled Workshop mod with SteamCMD — streaming from the Steam
# CDN with no 16s timeout — and place every one into mods/workshop-<id>/ (V1),
# the only mod location this server setup uses.
# 通过 SteamCMD 下载每个启用的工坊 mod（从 Steam CDN 流式下载，无 16 秒超时限制），
# 放入 mods/workshop-<id>/ (V1)，即本配置唯一使用的 mod 位置。
#
#   * NEW-format mods  -> SteamCMD already extracted the real files; just copy.
#                         新版 mod — SteamCMD 已解压真实文件，直接复制。
#   * LEGACY-format    -> SteamCMD leaves a single _legacy.bin ZIP; we unzip it
#                         so the server finds modinfo.lua/modmain.lua.
#                         (The server cannot read .bin on its own, and its
#                         built-in downloader times out on slow networks.)
#                         旧版 mod — SteamCMD 仅保留 _legacy.bin 压缩包，
#                         需解压才能让服务端找到 modinfo.lua/modmain.lua。
#                         (服务端无法直接读取 .bin，内置下载器在慢速网络下会超时)
#
# The server is launched with -skip_update_server_mods, so it never runs its
# own Workshop downloader and never wipes these directories.
# 服务端以 -skip_update_server_mods 启动，不会运行自带下载器，也不会覆盖这些目录。
#
# 322330 = DST client/Workshop appid (Workshop content lives under it), not 343050.
# 322330 = DST 客户端/工坊 appid（工坊内容存放于此 appid 下），非 343050。
WS_CONTENT="$DST_DIR/steamapps/workshop/content/322330"

# Parse enabled Workshop IDs from modoverrides.lua — the single source of truth.
# Skip "--" comment lines like the examples.
# 从 modoverrides.lua 解析启用的工坊 ID（唯一权威来源），跳过示例中的 "--" 注释行。
echo "SCANNING MOD_IDS FROM $modoverrides"
mod_ids=$(grep -vE '^[[:space:]]*--' "$modoverrides" 2>/dev/null \
          | grep -oE 'workshop-[0-9]+' | grep -oE '[0-9]+' | sort -u || true)
echo "MOD_IDS = ${mod_ids//$'\n'/ }"

for id in $mod_ids; do
  # A valid V1 install requires modinfo.lua; reuse it if already present.
  # 有效的 V1 安装需包含 modinfo.lua；若已存在则跳过，避免重复下载。
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
    # 新版 mod — SteamCMD 已解压真实文件 → 复制。
    cp -a "$WS_CONTENT/$id" "$DST_DIR/mods/workshop-$id"
    echo ">> Installed new-format mod $id -> mods/workshop-$id"
  elif ls "$WS_CONTENT/$id"/*_legacy.bin >/dev/null 2>&1; then
    # LEGACY-format mod: SteamCMD left a single _legacy.bin ZIP. Unpack it so the
    # server finds modinfo.lua/modmain.lua (it cannot read the .bin on its own).
    # 旧版 mod — SteamCMD 仅保留 _legacy.bin 压缩包。解压使服务端可读取
    # modinfo.lua/modmain.lua（服务端无法直接读取 .bin 文件）。
    unzip -o -q "$WS_CONTENT/$id"/*_legacy.bin -d "$DST_DIR/mods/workshop-$id"
    echo ">> Installed legacy-format mod $id (unpacked _legacy.bin) -> mods/workshop-$id"
  else
    echo ">> ERROR: mod $id downloaded but no modinfo.lua and no _legacy.bin at $WS_CONTENT/$id"
  fi
done
echo "================================================"
echo "============= MODS INSTALL DONE ================"
echo "============= MOD 安装完成 ====================="
echo "================================================"

echo "================================================"
echo "============= RUNNING DST ======================"
echo "============= 正在启动 DST ====================="
echo "================================================"
if [ ! -x "$DST_DIR/bin/dontstarve_dedicated_server_nullrenderer" ]; then
  echo "ERROR: dst_server_cache binary not found at $DST_DIR/bin."
  echo "       The steamcmd install did not place files in the install dir."
  echo "       Check that $DST_DIR is writable by user dst and re-run."
  echo "错误：未在 $DST_DIR/bin 下找到 dst_server_cache 二进制文件。"
  echo "      steamcmd 安装未将文件写入安装目录。"
  echo "      请检查 $DST_DIR 是否对 dst 用户可写，然后重新运行。"
  exit 1
fi
cd "$DST_DIR/bin"
# -skip_update_server_mods: start.sh already fetched + unpacked every mod above.
# The server's own downloader must NOT run — it downloads to ugc_mods/ (wiping
# our mods/workshop-<id>/ copies) and times out (result 16) on slow networks.
# -skip_update_server_mods：start.sh 已在上方拉取并解压所有 mod。
# 服务端自带的下载器不可运行 — 它会下载到 ugc_mods/（覆盖
# mods/workshop-<id>/ 副本）并在慢速网络下超时（返回码 16）。
./dontstarve_dedicated_server_nullrenderer -shard "$SHARD_NAME" -skip_update_server_mods
