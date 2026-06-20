# ---------------------------------------------------------------------------
# Don't Starve Together dedicated server image.
#
# The image only contains SteamCMD plus the 32-bit runtime libraries the server
# needs. The DST server itself is NOT baked into the image; it is downloaded on
# first boot by start.sh and stored on a mounted volume, so updating the game
# never requires rebuilding the image.
# ---------------------------------------------------------------------------
FROM debian:13-slim

# DST's dedicated server binary is 32-bit (i386), so we enable the i386 package
# architecture and pull in the matching runtime libraries:
#   ca-certificates, wget          -> fetch SteamCMD over HTTPS
#   lib32gcc-s1, lib32stdc++6      -> 32-bit C/C++ runtime the server links against
#   libcurl4-gnutls-dev:i386       -> 32-bit cURL the server uses for networking
# --no-install-recommends + removing apt lists keeps the image small.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates wget \
        lib32gcc-s1 lib32stdc++6 libcurl4-gnutls-dev:i386 && \
    rm -rf /var/lib/apt/lists/*

# Run as an unprivileged user instead of root (defense in depth: if the game
# server is ever compromised, it has no root inside the container).
RUN useradd -ms /bin/bash dst

# Download and unpack SteamCMD (Valve's CLI used to install/update Steam apps).
WORKDIR /home/dst/steamcmd
RUN wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && \
tar -xvzf steamcmd_linux.tar.gz

# Pre-create the install dir and hand the whole home dir to the dst user so the
# game files (downloaded later) can be written without root.
RUN mkdir -p /home/dst/DST/mods && chown -R dst:dst /home/dst
USER dst
WORKDIR /home/dst

# Persist the cluster config + world saves. Do NOT declare /home/dst/DST as a
# VOLUME: compose already bind-mounts ./DST over it, and a VOLUME on the install
# dir creates a root-owned anonymous volume (especially for mods/) that steamcmd
# (running as user dst) cannot write to during install -> state 0x602.
VOLUME [ "/home/dst/.klei/DoNotStarveTogether" , "/home/dst/DST"]

# start.sh is the entrypoint: it installs/updates DST, fetches mods, then boots
# the requested shard. compose also bind-mounts it so edits apply on restart.
COPY ./start.sh /home/dst/
ENTRYPOINT ["/home/dst/start.sh"]