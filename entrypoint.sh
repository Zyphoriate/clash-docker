#!/usr/bin/env bash
# entrypoint.sh — 全部交给原项目 clashctl 处理
set -e

export CLASHCTL_HOME="${CLASHCTL_HOME:-/opt/clashctl}"

# ── 加载原项目环境 & 脚本 ──────────────────────────────────────────────────
source "${CLASHCTL_HOME}/.env" 2>/dev/null || true

for lib in "${CLASHCTL_HOME}/scripts/lib/"*.sh; do
    [ -f "$lib" ] && source "$lib"
done

for cmd in "${CLASHCTL_HOME}/scripts/cmd/"*.sh; do
    [[ "$cmd" != *clashctl.* ]] && [ -f "$cmd" ] && source "$cmd"
done

# ── 1. 设置访问密钥 ───────────────────────────────────────────────────────
if [ -n "${SECRET}" ]; then
    echo "==> Setting secret..."
    clashsecret "${SECRET}"
fi

# ── 2. 拉取订阅 ──────────────────────────────────────────────────────────
if [ -n "${CLASH_SUBSCRIBE_URL}" ]; then
    echo "==> Adding subscription..."
    clashsub add --use "${CLASH_SUBSCRIBE_URL}"
fi

# ── 3. 启动代理（容器环境自动走 nohup 模式）───────────────────────────────
echo "==> Starting via clashctl..."
clashon

# ── 4. 保持容器存活（等待 nohup 启动的后台内核进程）──────────────────────
wait
