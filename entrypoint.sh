#!/usr/bin/env bash
# entrypoint.sh — 使用原项目 clashctl CLI 处理订阅、密钥、配置合并
set -e

CLASHCTL_HOME="${CLASHCTL_HOME:-/opt/clashctl}"
export CLASHCTL_HOME

# ── 加载原项目环境与脚本 ──────────────────────────────────────────────────
source "${CLASHCTL_HOME}/.env" 2>/dev/null || true

for lib in "${CLASHCTL_HOME}/scripts/lib/"*.sh; do
    [ -f "$lib" ] && source "$lib"
done

for cmd in "${CLASHCTL_HOME}/scripts/cmd/"*.sh; do
    [[ "$cmd" != *clashctl.* ]] && [ -f "$cmd" ] && source "$cmd"
done

# ── 辅助：杀掉 nohup 模式启动的后台内核进程 ──────────────────────────────
_stray_kill() {
    local name="${CLASHCTL_KERNEL:-mihomo}"
    pkill -x "$name" 2>/dev/null || true
    sleep 0.3
}

# ── 1. 设置 Web 面板访问密钥 ─────────────────────────────────────────────
if [ -n "${SECRET}" ]; then
    echo "==> Setting dashboard secret..."
    clashsecret "${SECRET}" || echo "==> WARNING: secret setup failed"
    _stray_kill
fi

# ── 2. 拉取并激活订阅 ────────────────────────────────────────────────────
if [ -n "${CLASH_SUBSCRIBE_URL}" ]; then
    echo "==> Adding subscription: ${CLASH_SUBSCRIBE_URL}"
    clashsub add --use "${CLASH_SUBSCRIBE_URL}" || echo "==> WARNING: subscription add failed"
    _stray_kill
fi

# ── 3. 合并 base + mixin → runtime ───────────────────────────────────────
echo "==> Generating runtime config..."
_merge_config 2>/dev/null || true

# ── 4. 确定内核二进制 ────────────────────────────────────────────────────
KERNEL_BIN="${CLASHCTL_HOME}/bin/${CLASHCTL_KERNEL:-mihomo}"
[ -x "$KERNEL_BIN" ] || KERNEL_BIN="${CLASHCTL_HOME}/bin/clash"
[ -x "$KERNEL_BIN" ] || { echo "ERROR: no kernel binary found"; exit 1; }

RUNTIME_YAML="${CLASH_CONFIG_RUNTIME:-${CLASHCTL_HOME}/resources/runtime.yaml}"

echo "==> Starting $(basename "$KERNEL_BIN")..."
echo "==> Proxy: 0.0.0.0:7890 | API: 0.0.0.0:9090"

exec "${KERNEL_BIN}" -d "${CLASH_RESOURCES_DIR}" -f "${RUNTIME_YAML}"
