#!/usr/bin/env bash
set -e

CLASHCTL_HOME="${CLASHCTL_HOME:-/opt/clashctl}"
RESOURCES_DIR="${CLASHCTL_HOME}/resources"
CONFIG_BASE="${RESOURCES_DIR}/config.yaml"
CONFIG_MIXIN="${RESOURCES_DIR}/mixin.yaml"
CONFIG_RUNTIME="${RESOURCES_DIR}/runtime.yaml"
PROFILES_DIR="${RESOURCES_DIR}/profiles"
BIN_DIR="${CLASHCTL_HOME}/bin"

mkdir -p "${RESOURCES_DIR}" "${PROFILES_DIR}"

# ── 1. Determine kernel binary ──────────────────────────────────────────────
if [ -f "${BIN_DIR}/mihomo" ]; then
    KERNEL_BIN="${BIN_DIR}/mihomo"
elif [ -f "${BIN_DIR}/clash" ]; then
    KERNEL_BIN="${BIN_DIR}/clash"
else
    echo "Error: No kernel binary found in ${BIN_DIR}"
    exit 1
fi
echo "==> Kernel: $(basename "${KERNEL_BIN}")"

# ── 2. Handle subscription / config ────────────────────────────────────────
if [ -n "${CLASH_SUBSCRIBE_URL}" ]; then
    echo "==> Downloading subscription: ${CLASH_SUBSCRIBE_URL}"

    # Download with retry
    SUB_TMP="${RESOURCES_DIR}/sub.tmp.yaml"
    for i in 1 2 3; do
        if curl -fsSL --connect-timeout 15 --retry 2 \
            -A "mihomo" \
            "${CLASH_SUBSCRIBE_URL}" -o "${SUB_TMP}"; then
            break
        fi
        echo "==> Retry ${i}/3..."
        sleep 2
    done

    # Validate: check file is non-empty and looks like YAML/Clash config
    if [ ! -s "${SUB_TMP}" ]; then
        echo "==> ERROR: Downloaded subscription is empty"
        exit 1
    fi

    # Check if it's HTML (common when URL is wrong or needs auth)
    if grep -qiE '^\s*<!DOCTYPE|<html|<head|<body' "${SUB_TMP}"; then
        echo "==> ERROR: Subscription returned HTML, not a valid config (check your URL)"
        exit 1
    fi

    # Remove BOM and normalize line endings
    sed -i '1s/^\xEF\xBB\xBF//' "${SUB_TMP}"
    sed -i 's/\r$//' "${SUB_TMP}"

    # Check if it has proxies or proxy-providers (valid clash config)
    if grep -qE '^\s*(proxies|proxy-providers):' "${SUB_TMP}"; then
        echo "==> Valid Clash config detected"
    else
        # Might be a base64-encoded or encrypted subscription
        # Try running through subconverter if available
        if [ -f "${BIN_DIR}/subconverter/subconverter" ]; then
            echo "==> Non-standard format, attempting subconverter..."
            # (subconverter handling would go here)
        fi
        echo "==> Warning: config format may not be standard, trying anyway"
    fi

    # Save as profile and activate
    cp "${SUB_TMP}" "${PROFILES_DIR}/1.yaml"
    cp "${SUB_TMP}" "${CONFIG_BASE}"
    rm -f "${SUB_TMP}"
    echo "==> Subscription activated → ${CONFIG_BASE}"

elif [ -f "${CONFIG_BASE}" ]; then
    echo "==> Using existing config: ${CONFIG_BASE}"

else
    # No subscription, no existing config → generate minimal default
    echo "==> No config found, generating default..."
    cat > "${CONFIG_BASE}" << 'YAML'
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
secret: ""

proxies: []
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,DIRECT
YAML
fi

# ── 3. Merge config (base + mixin → runtime) ──────────────────────────────
if [ -f "${BIN_DIR}/yq" ] && [ -f "${CONFIG_MIXIN}" ] && [ -s "${CONFIG_MIXIN}" ]; then
    echo "==> Merging mixin config..."
    "${BIN_DIR}/yq" eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        "${CONFIG_BASE}" "${CONFIG_MIXIN}" > "${CONFIG_RUNTIME}" 2>/dev/null || {
        echo "==> Warning: yq merge failed, using base config only"
        cp "${CONFIG_BASE}" "${CONFIG_RUNTIME}"
    }
else
    cp "${CONFIG_BASE}" "${CONFIG_RUNTIME}"
fi

# ── 4. Start kernel ────────────────────────────────────────────────────────
echo "==> Starting $(basename "${KERNEL_BIN}")..."
echo "==> Proxy:    0.0.0.0:7890 (HTTP/SOCKS mixed)"
echo "==> API/UI:   0.0.0.0:9090"

exec "${KERNEL_BIN}" -d "${RESOURCES_DIR}" -f "${CONFIG_RUNTIME}"
