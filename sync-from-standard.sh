#!/bin/bash
# Sync GWD split-routing generation scripts from the reference (standard) machine.
# Usage: ./sync-from-standard.sh [standard_host]
# Default standard: degwd (248)

set -o pipefail

STANDARD="${1:-degwd}"
CUSTOM_DIR="/opt/de_GWD/.custom"

echo "============================================"
echo " Sync from standard: $STANDARD"
echo "============================================"

# ── 1. Sync generation scripts ──
SCRIPTS=(
    ui_4h ui_4am ui_2h
    ui-smartDNS ui-DNSsplit ui-submitListBW ui-NodeSave
    ui-healCheck ui-NodeOne
)
echo ""
echo "[1/4] Syncing generation scripts..."
mkdir -p "$CUSTOM_DIR"
for s in "${SCRIPTS[@]}"; do
    if scp -q "root@${STANDARD}:/opt/de_GWD/${s}" "${CUSTOM_DIR}/${s}" 2>/dev/null; then
        chmod +x "${CUSTOM_DIR}/${s}"
        echo "  ✓ $s"
    else
        echo "  ✗ $s (skip, may not exist on standard)"
    fi
done

# ── 2. Sync shared 0conf fields (preserve local IP/gateway) ──
echo ""
echo "[2/4] Syncing shared 0conf fields..."

if [[ ! -f "/opt/de_GWD/0conf" ]]; then
    echo "  ✗ No local 0conf found, skipping"
else
    # Extract local machine-specific fields
    LOCAL_IP=$(jq -r '.address.localIP' /opt/de_GWD/0conf)
    LOCAL_GW=$(jq -r '.address.upstreamIP' /opt/de_GWD/0conf)
    LOCAL_ALIAS=$(jq -r '.address.alias' /opt/de_GWD/0conf)
    LOCAL_PWD=$(jq -r '.address.PWD' /opt/de_GWD/0conf)

    # Pull shared fields from standard
    # wireguard + ddns excluded: contain private keys and API credentials
    SHARED_JSON=$(ssh "root@${STANDARD}" "jq '{dns, v2node, v2nodeDIV, app, rulesIP, update}' /opt/de_GWD/0conf" 2>/dev/null)
    if [[ -n "$SHARED_JSON" ]]; then
        # Merge: keep local machine-specific, apply standard shared
        jq --argjson shared "$SHARED_JSON" \
           --arg localIP "$LOCAL_IP" \
           --arg upstreamIP "$LOCAL_GW" \
           --arg alias "$LOCAL_ALIAS" \
           --arg PWD "$LOCAL_PWD" \
           '.address.localIP = $localIP |
            .address.upstreamIP = $upstreamIP |
            .address.alias = $alias |
            .address.PWD = $PWD |
            . * $shared' \
           /opt/de_GWD/0conf | sponge /opt/de_GWD/0conf
        chmod 666 /opt/de_GWD/0conf
        echo "  ✓ Shared DNS/node/rule config merged"
        echo "  ✓ Local IP/GW/Alias/PWD preserved"
    else
        echo "  ✗ Failed to fetch shared config from standard"
    fi
fi

# ── 3. Sync data files (if newer on standard) ──
echo ""
echo "[3/5] Syncing data files..."
DATA_FILES=(
    "IPchnroute"
    "Domains.chn.txt"
    "geoip.dat"
    "geosite.dat"
)
for f in "${DATA_FILES[@]}"; do
    scp -q "root@${STANDARD}:/opt/de_GWD/.repo/${f}" "/opt/de_GWD/.repo/${f}" 2>/dev/null && \
        echo "  ✓ $f" || echo "  ✗ $f"
done

# ── 4. Sync Pi-hole gravity.db (schema from standard) ──
echo ""
echo "[4/5] Syncing Pi-hole gravity.db..."
GRAVITY_DB="/etc/pihole/gravity.db"
# 248 uses Docker Pi-hole, extract from container
ssh "root@${STANDARD}" "docker cp pihole:/etc/pihole/gravity.db /tmp/gravity.db 2>/dev/null && cat /tmp/gravity.db" 2>/dev/null > "${GRAVITY_DB}.new"
if [[ -s "${GRAVITY_DB}.new" ]]; then
    mv "${GRAVITY_DB}.new" "$GRAVITY_DB"
    chown pihole:pihole "$GRAVITY_DB" 2>/dev/null || true
    systemctl restart pihole-FTL 2>/dev/null || true
    echo "  ✓ gravity.db synced"
else
    rm -f "${GRAVITY_DB}.new"
    echo "  ✗ gravity.db (skip, may need manual setup)"
fi

# ── 5. Regenerate rules ──
echo ""
echo "[5/5] Regenerating rules..."
/opt/de_GWD/.custom/ui_4h 2>/dev/null && echo "  ✓ ui_4h completed"
/opt/de_GWD/.custom/ui_4am 2>/dev/null && echo "  ✓ ui_4am completed"

echo ""
echo "============================================"
echo " Sync complete. Run 'systemctl restart vtrui nftables' if needed."
echo "============================================"
