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

# ── 2. 设置 mixin（bind 0.0.0.0 + 密钥），然后应用合并 ─────────────────
MIXIN="${CLASH_CONFIG_MIXIN:-${CLASHCTL_HOME}/resources/mixin.yaml}"
touch "${MIXIN}"
"${BIN_YQ}" -i '.allow-lan = true | ."bind-address" = "*"' "${MIXIN}" 2>/dev/null || true

if [ -n "${SECRET}" ]; then
    echo "==> Setting secret..."
    clashsecret "${SECRET}" || echo "==> WARNING: secret setup failed"
    # clashsecret 内部已调用 _merge_config_restart
else
    echo "==> Applying mixin..."
    _merge_config_restart 2>/dev/null || true
fi

# ── 3. 启动代理 ──────────────────────────────────────────────────────────
echo "==> Starting via clashctl..."
clashon || { echo "==> ERROR: clashon failed"; exit 1; }

# ── 4. 保活：tail -f 项目日志（nohup 模式输出到此文件）──────────────────
LOG_FILE="${CLASH_RESOURCES_DIR:-${CLASHCTL_HOME}/resources}/${CLASHCTL_KERNEL:-mihomo}.log"
touch "${LOG_FILE}"
echo "==> Tailing log: ${LOG_FILE}"
exec tail -f "${LOG_FILE}"
