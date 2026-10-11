#!/bin/bash
# Wake the server via Wake-on-LAN and wait until SSH is reachable.
# Firmware default is Windows (REMOTE_HOST); the probe also accepts the Ubuntu
# install (UBUNTU_HOST) in case the machine boots into it instead.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
_load_config

echo "[1/3] Sending WOL packet to $REMOTE_HOST ($WOL_MAC)..."
wakeonlan "$WOL_MAC"

echo -n "[2/3] Waiting for $REMOTE_HOST to boot up "
for _ in {1..40}; do
    for host in "$REMOTE_HOST" "$UBUNTU_HOST"; do
        if ssh -q -o ConnectTimeout=5 "$host" exit 2>/dev/null; then
            echo -e "\n[3/3] $REMOTE_HOST is online ($host reachable)!"
            sleep 1
            exit 0
        fi
    done
    echo -n "."
    sleep 3
done
echo -e "\nTimeout! $REMOTE_HOST failed to boot or tunnel is offline."
exit 1
