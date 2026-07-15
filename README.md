# Clash Docker 镜像

基于 [clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install) 打包的 Docker 镜像。

## 快速开始

### 1. 设置订阅地址

在 `.env` 文件中填入你的订阅链接：

```bash
CLASH_SUBSCRIBE_URL=https://your-subscription-url
```

### 2. 启动

```bash
docker-compose up -d
```

容器启动后会自动拉取订阅并激活。

### 3. 查看日志

```bash
docker-compose logs -f
```

## 端口

| 端口 | 用途 |
|------|------|
| 7890 | HTTP / SOCKS 混合代理 |
| 9090 | Web 面板 / REST API |

## 文件结构

```
.
├── Dockerfile
├── docker-compose.yml
├── .env                  # 填入订阅地址
├── entrypoint.sh         # 容器启动脚本
└── resources/            # 挂载到容器 /opt/clashctl/resources
    ├── config.yaml       # 激活的配置
    ├── mixin.yaml        # 自定义覆盖配置（可选）
    └── profiles/         # 订阅缓存
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `CLASH_SUBSCRIBE_URL` | 订阅链接，启动时自动拉取并激活为当前配置 |
| `TZ` | 时区，默认 `Asia/Shanghai` |

## 使用宿主机上的配置

如果你已有 `config.yaml`，直接放到 `./resources/` 目录下即可，启动时会优先使用已有配置：

```bash
cp /path/to/your/config.yaml ./resources/
docker-compose up -d
```

## 自定义 mixin 覆盖

在 `./resources/mixin.yaml` 中写入需要覆盖的配置项，启动时会自动合并到运行时配置中。

## TUN 模式

如需 TUN 模式，在 `docker-compose.yml` 中取消注释：

```yaml
cap_add:
  - NET_ADMIN
devices:
  - /dev/net/tun
```
