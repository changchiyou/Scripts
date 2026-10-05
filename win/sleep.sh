#!/bin/bash
# Power off the server while it runs Windows (via Windows OpenSSH).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config

echo "Shutting down $REMOTE_HOST (Windows)..."
win "powershell.exe -NoProfile -Command Stop-Computer -Force"
echo "Power off command sent."
