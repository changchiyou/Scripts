#!/bin/bash
# Wake the server via Wake-on-LAN and wait until SSH is reachable.
# OS-agnostic: the firmware boots the default disk (Windows).
# To boot the other OS afterwards, use ubuntu/boot-ubuntu.sh (run while Windows is up).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
_load_config

echo "[1/3] Sending WOL packet to $REMOTE_HOST ($WOL_MAC)..."
wakeonlan "$WOL_MAC"

echo -n "[2/3] Waiting for $REMOTE_HOST to boot up "
for _ in {1..40}; do
    if ssh -q -o ConnectTimeout=5 "$REMOTE_HOST" exit 2>/dev/null; then
        echo -e "\n[3/3] $REMOTE_HOST is online!"
        sleep 1
        exit 0
    fi
    echo -n "."
    sleep 3
done
echo -e "\nTimeout! $REMOTE_HOST failed to boot or tunnel is offline."
exit 1
