#!/bin/bash
# One-shot boot into Ubuntu (auto-reverts to the Windows default next reboot).
# Must run while Windows is up: it uses Windows bcdedit to arm the firmware
# bootsequence. Detection matches the EFI path (\EFI\ubuntu\shimx64.efi),
# not the localized description, so it works regardless of Windows locale.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config

echo "[1/3] Resolving Ubuntu firmware boot entry on $REMOTE_HOST..."
UBUNTU_GUID=""
for g in $(win "bcdedit /enum {fwbootmgr}" | grep -oE "[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}" | sort -u); do
    if win "bcdedit /enum {$g}" | grep -qi "ubuntu"; then
        UBUNTU_GUID=$g
    fi
done

if [ -z "$UBUNTU_GUID" ]; then
    echo "ERROR: Ubuntu entry not found in {fwbootmgr}." >&2
    exit 1
fi
echo "      Ubuntu entry: {$UBUNTU_GUID}"

echo "[2/3] Setting one-shot bootsequence..."
win "bcdedit /set {fwbootmgr} bootsequence {$UBUNTU_GUID}" > /dev/null

echo "[3/3] Rebooting $REMOTE_HOST into Ubuntu..."
win "shutdown /r /t 5" > /dev/null
echo "Done. This reboot boots Ubuntu; subsequent reboots revert to Windows."
