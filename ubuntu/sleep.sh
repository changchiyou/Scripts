#!/bin/bash
# Power off the server while it runs Ubuntu (via the GHS ssh alias).
# Needs a NOPASSWD sudoers rule for shutdown on the Ubuntu install:
#   echo "chris ALL=(ALL) NOPASSWD: /usr/sbin/shutdown" | sudo tee /etc/sudoers.d/chris-shutdown
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config

echo "Shutting down $UBUNTU_HOST (Ubuntu)..."
ssh "$UBUNTU_HOST" "sudo shutdown -h now"
echo "Power off command sent."
