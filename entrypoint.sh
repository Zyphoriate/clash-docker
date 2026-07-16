#!/usr/bin/env bash
# entrypoint.sh — 加载原项目 clashctl CLI，由它处理一切

export CLASHCTL_HOME="${CLASHCTL_HOME:-/root/clashctl}"

# ── 加载原项目环境 & 脚本 ──────────────────────────────────────────────────
source "${CLASHCTL_HOME}/.env" 2>/dev/null || true

for lib in "${CLASHCTL_HOME}/scripts/lib/"*.sh; do
    [ -f "$lib" ] && source "$lib"
done

for cmd in "${CLASHCTL_HOME}/scripts/cmd/"*.sh; do
    [[ "$cmd" != *clashctl.* ]] && [ -f "$cmd" ] && source "$cmd"
done

# ── 1. 拉取订阅（已存在则跳过）───────────────────────────────────────────
if [ -n "${CLASH_SUBSCRIBE_URL}" ]; then
    echo "==> Adding subscription..."
    clashsub add --use "${CLASH_SUBSCRIBE_URL}" || echo "==> WARNING: subscription add failed, continuing..."
fi

# ── 2. 设置密钥（确保 mixin.yaml 存在，在启动前设好避免重启）───────────
if [ -n "${SECRET}" ]; then
    echo "==> Setting secret..."
    touch "${CLASH_CONFIG_MIXIN:-${CLASHCTL_HOME}/resources/mixin.yaml}"
    clashsecret "${SECRET}" || echo "==> WARNING: secret setup failed"
fi

# ── 3. 启动代理 ──────────────────────────────────────────────────────────
echo "==> Starting via clashctl..."
clashon || { echo "==> ERROR: clashon failed"; exit 1; }

# ── 4. 保活：跟踪内核 PID，崩溃时打印日志 ────────────────────────────────
KERNEL="${CLASHCTL_KERNEL:-mihomo}"
LOG_FILE="${CLASH_RESOURCES_DIR:-${CLASHCTL_HOME}/resources}/${KERNEL}.log"

for i in $(seq 1 10); do
    PID=$(pgrep -x "$KERNEL" 2>/dev/null | head -1)
    [ -n "$PID" ] && break
    sleep 0.5
done

if [ -z "$PID" ]; then
    echo "==> ERROR: ${KERNEL} failed to start"
    echo "==> Last 50 lines of log:"
    tail -50 "${LOG_FILE}" 2>/dev/null || true
    exit 1
fi

echo "==> ${KERNEL} running (PID ${PID})"
wait "$PID" 2>/dev/null

echo "==> ${KERNEL} exited (PID ${PID}), last 50 lines of log:"
tail -50 "${LOG_FILE}" 2>/dev/null || true
exit 1
