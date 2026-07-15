#!/usr/bin/env bash
# entrypoint.sh — 全部交给原项目 clashctl 处理

export CLASHCTL_HOME="${CLASHCTL_HOME:-/opt/clashctl}"

# ── 加载原项目环境 & 脚本 ──────────────────────────────────────────────────
source "${CLASHCTL_HOME}/.env" 2>/dev/null || true

for lib in "${CLASHCTL_HOME}/scripts/lib/"*.sh; do
    [ -f "$lib" ] && source "$lib"
done

for cmd in "${CLASHCTL_HOME}/scripts/cmd/"*.sh; do
    [[ "$cmd" != *clashctl.* ]] && [ -f "$cmd" ] && source "$cmd"
done

# ── 1. 拉取订阅（失败不退出，可能已存在或网络问题）───────────────────────
if [ -n "${CLASH_SUBSCRIBE_URL}" ]; then
    echo "==> Adding subscription..."
    clashsub add --use "${CLASH_SUBSCRIBE_URL}" || echo "==> WARNING: subscription add failed, continuing..."
fi

# ── 2. 启动代理（容器环境自动走 nohup 模式）───────────────────────────────
echo "==> Starting via clashctl..."
clashon || { echo "==> ERROR: clashon failed"; exit 1; }

# ── 3. 设置访问密钥（启动后再设，此时 mixin.yaml 已存在）─────────────────
if [ -n "${SECRET}" ]; then
    echo "==> Setting secret..."
    clashsecret "${SECRET}" || echo "==> WARNING: secret setup failed"
fi

# ── 4. 保持容器存活 ──────────────────────────────────────────────────────
wait
