<p align="center">
  <img src="https://img.shields.io/badge/游戏-饥荒联机版-8B4513?style=for-the-badge" alt="DST">
  <img src="https://img.shields.io/badge/运行环境-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/许可-MIT-green?style=for-the-badge" alt="MIT">
</p>

<br>

<div align="center">

# 🔥 饥荒联机版
### 🐳 Docker 专用服务器

**运行属于你自己的世界 — 持久在线，尽在掌控。**

`森林 + 洞穴` · `SteamCMD 自动安装` · `启动即下 Mod` · `非 root`

<br>

<sub>📖 <a href="./README.md">English</a> · 中文</sub>

</div>

<br>

一条 `docker compose up`，足矣。两个容器 — 主世界与洞穴 — 构成无缝统一世界。SteamCMD 自动安装、工坊 mod 启动即下载、重启即更新。无需折腾。你的服务器，你来定规矩。

---

## 为什么需要它

手动搭建 DST 服务器需要应对 SteamCMD、32 位运行库、动不动就超时的 mod 下载，以及两个必须互相发现的进程。本项目将这一切封装为一条 `docker compose up` 命令。仓库拉下来，填入配置，启动。你的世界便已在线。

---

## 快速开始

### 环境要求

- **Docker** (24+) 和 **Docker Compose** (v2)
- 一台 Linux 主机，至少 4 GB 内存、10 GB 磁盘空间
- 一个 [Klei 账号](https://accounts.klei.com)，用于生成服务器令牌

### 1. 克隆仓库

```bash
git clone <repo-url> dst-server && cd dst-server
```

### 2. 获取服务器令牌

1. 访问 [Klei 账户 - 游戏](https://accounts.klei.com/account/game/servers?game=DontStarveTogether)
2. 输入名称，点击 **Generate Server Token**
3. 复制令牌字符串
4. 粘贴到 `dst_config/cluster_token.txt` 文件中

### 3. 命名你的世界

编辑 `dst_config/cluster.ini`，至少填入以下内容：

```ini
cluster_name = 我的世界
cluster_description = 欢迎！
cluster_password = 你的密码
cluster_key = 任意随机字符串
```

> `cluster_key` 是主世界与洞穴之间的共享密钥。生成一个随机字符串即可，它不会离开你的主机。

### 4. （可选）选择你的 Mod

编辑 `dst_config/mods/modoverrides.lua` — 取消你需要的 mod 注释并设置 `enabled=true`。已预置四个常用品质 mod 作为示例。

### 5. 启动服务器

```bash
docker compose up -d
```

首次启动时 SteamCMD 会下载 DST 服务端（约 3 GB）。后续启动即时完成。

你的服务器现在已在 DST 游戏内服务器列表中可见。

---

## 文件结构

```
.
├── Dockerfile            # 镜像定义（Debian + SteamCMD + 32 位运行库）
├── docker-compose.yml    # 双容器编排
├── start.sh              # 入口脚本：安装 → mod → 启动
├── .env.example          # 端口/名称覆盖的模板文件
├── dst_config/
│   ├── cluster.ini       # 服务器名称、密码、游戏规则
│   ├── cluster_token.txt # Klei 认证令牌（已 gitignore）
│   ├── Master/
│   │   ├── server.ini    # 主世界网络配置
│   │   └── leveldataoverride.lua  # 世界生成设置（森林）
│   ├── Caves/
│   │   ├── server.ini    # 洞穴网络配置
│   │   └── leveldataoverride.lua  # 世界生成设置（地下）
│   └── mods/
│       └── modoverrides.lua  # 已启用 mod 及各项设置
└── dst_server_cache/     # 游戏二进制文件及 mod 下载（已 gitignore）
```

---

## 日常操作

### 查看服务器状态

```bash
docker compose ps
docker compose logs -f --tail=50
```

### 修改配置后重启

```bash
docker compose restart
```

配置文件通过 bind mount 挂载，无需重构建。

### 更新游戏

```bash
docker compose down && docker compose up -d
```

`start.sh` 在每次启动时运行 SteamCMD，因此重启即更新。

### 查看在线玩家

服务端日志会显示玩家加入/离开事件。如需更丰富的管理工具，可在 `cluster.ini` 中启用控制台，使用 DST 内置的远程指令。

---

## 配置速查

| 文件 | 控制内容 |
|---|---|
| `cluster.ini` | 游戏模式、人数上限、PvP、服务器名称、密码 |
| `Master/server.ini` | 主世界端口（默认 11999）、分片标识 |
| `Caves/server.ini` | 洞穴端口（默认 11998）、分片标识 |
| `Master/leveldataoverride.lua` | 森林世界生成（生物、资源、季节） |
| `Caves/leveldataoverride.lua` | 洞穴世界生成（蠕虫、蘑菇、噩梦循环） |
| `mods/modoverrides.lua` | 启用的工坊 mod 及其设置 |
| `.env` | 覆盖容器名称及主机端口 |

### 自定义 .env

```bash
cp .env.example .env
```

编辑 `.env` 以修改容器名或发布端口。所有值均有合理的默认值，可删除不需要的行。

---

## Mod 管理

Mod 定义于 `dst_config/mods/modoverrides.lua`，语法如下：

```lua
["workshop-<mod-id>"] = {
  configuration_options = { ... },
  enabled = true
}
```

启动脚本会在每次启动时自动下载并安装所有已启用的 mod，无需手动运行 SteamCMD 指令。

---

## 安全说明

- 服务端在容器内以非特权用户运行（`dst`，非 `root`）
- `cluster_token.txt`、`cluster.ini`、`adminlist.txt` 已被 gitignore — 密钥不会入库
- 仅需对外暴露 UDP 端口 11998–11999；服务端不使用 TCP

---

## 常见问题

| 问题 | 可能解决方案 |
|---|---|
| 服务器在列表中不显示 | 检查 `cluster_token.txt` 是否有效；确认防火墙已放行 UDP 11998–11999 |
| 洞穴无法连接主世界 | 确认 `dst_config/cluster.ini` 中 `cluster_key` 两侧一致 |
| Mod 不加载 | 查看 `docker compose logs` — mod ID 需在 `modoverrides.lua` 中取消注释 |
| 首次启动较慢 | 正常现象 — SteamCMD 正在下载约 3 GB 服务端。等待约 5–10 分钟 |

---

## 许可

MIT — 自由建服，自由分享配置，自由扩展。
