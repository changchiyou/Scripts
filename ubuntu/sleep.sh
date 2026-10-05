#!/bin/bash
# Power off the server while it runs Ubuntu (via Linux sshd).
# Requires sshd + tunnel client installed on the Ubuntu install,
# otherwise the SSH tunnel is dead once Windows is off.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config

echo "Shutting down $REMOTE_HOST (Ubuntu)..."
ssh "$REMOTE_HOST" "sudo shutdown -h now"
echo "Power off command sent."
