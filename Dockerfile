# ===========================================================================
# Don't Starve Together — Dedicated Server Image
# 饥荒联机版 — 专用服务器镜像
#
# This image contains only SteamCMD plus the 32-bit runtime libraries the
# server needs. The DST server itself is NOT baked into the image; it is
# downloaded on first boot by start.sh and stored on a mounted volume, so
# updating the game never requires rebuilding the image.
# 此镜像仅包含 SteamCMD 和服务端所需的 32 位运行库。DST 服务端本身不内置 —
# 由 start.sh 在首次启动时下载并存入挂载卷中。更新游戏无需重构建镜像。
# ===========================================================================
FROM debian:13-slim

# DST's dedicated server binary is 32-bit (i386), so we enable the i386 package
# architecture and pull in the matching runtime libraries.
# DST 服务端为 32 位 (i386)，故启用 i386 架构并安装对应运行库。
#
#   ca-certificates, wget          -> fetch SteamCMD over HTTPS
#                                    通过 HTTPS 下载 SteamCMD
#   unzip                          -> unpack legacy Workshop mods (steamcmd leaves
#                                     them as a single _legacy.bin ZIP archive)
#                                    解压旧版工坊 mod（steamcmd 保留为 _legacy.bin 压缩包）
#   lib32gcc-s1, lib32stdc++6      -> 32-bit C/C++ runtime the server links against
#                                    服务端依赖的 32 位 C/C++ 运行时
#   libcurl4-gnutls-dev:i386       -> 32-bit cURL the server uses for networking
#                                    服务端使用的 32 位 cURL 网络库
#
# --no-install-recommends + removing apt lists keeps the image small.
# --no-install-recommends 并清理 apt 缓存以减小镜像体积。
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget unzip \
        lib32gcc-s1 lib32stdc++6 libcurl4-gnutls-dev:i386 && \
    rm -rf /var/lib/apt/lists/*

# Run as an unprivileged user instead of root — defense in depth.
# If the game server is ever compromised, it has no root inside the container.
# 以非特权用户运行而非 root — 纵深防御。
# 若服务端被攻破，攻击者在容器内无 root 权限。
RUN useradd -ms /bin/bash dst

# Download and unpack SteamCMD — Valve's CLI for installing/updating Steam apps.
# 下载并解压 SteamCMD — Valve 官方 Steam 应用安装/更新命令行工具。
WORKDIR /home/dst/steamcmd
RUN wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && \
tar -xvzf steamcmd_linux.tar.gz

# Pre-create the install directory and hand ownership to the dst user.
# Game files (downloaded later) can then be written without root.
# 预创建安装目录并将所有权交给 dst 用户，后续下载的游戏文件无需 root 即可写入。
RUN mkdir -p /home/dst/dst_server_cache/mods && chown -R dst:dst /home/dst
USER dst
WORKDIR /home/dst

# Persist the cluster config + world saves across container restarts.
# Do NOT declare /home/dst/DST as a VOLUME — compose already bind-mounts over it,
# and a VOLUME on the install dir creates a root-owned anonymous volume that
# steamcmd (running as user dst) cannot write to during install → state 0x602.
# 持久化集群配置及世界存档。
# 切勿将 /home/dst/DST 声明为 VOLUME — compose 已通过 bind mount 覆盖；
# 若在安装目录上声明 VOLUME 会创建 root 所有的匿名卷，
# 导致以 dst 用户运行的 steamcmd 写入失败 → 报错 state 0x602。
VOLUME [ "/home/dst/.klei/DoNotStarveTogether" ]

# start.sh is the entrypoint: it installs/updates DST, fetches mods, then boots
# the requested shard. compose also bind-mounts it so edits apply on restart
# without requiring a rebuild.
# start.sh 为入口脚本：安装/更新 DST → 拉取 mod → 启动指定分片。
# compose 通过 bind mount 挂载，修改后重启即生效，无需重构建镜像。
COPY ./start.sh /home/dst/
ENTRYPOINT ["/home/dst/start.sh"]
