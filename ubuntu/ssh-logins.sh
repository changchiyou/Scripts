#!/bin/bash
# SSH login records + source IPs from the Ubuntu host (GHS). No sudo needed
# (reader is in the `adm` group; auth.log/journal are group-readable).
# Usage: ssh-logins.sh [days]     (default: 7)
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
_load_config

DAYS="${1:-7}"

ssh "$UBUNTU_HOST" DAYS="$DAYS" 'bash -s' <<'REMOTE'
since="${DAYS} days ago"

echo "=== Successful logins (last, since wtmp start) ==="
# LC_ALL=C: stable (English) timestamps so the sed below matches.
export LC_ALL=C
last -F -s "$(date -d "$since" '+%Y-%m-%d %H:%M:%S')" 2>/dev/null | grep -vE '^(wtmp|reboot|$)'

echo
echo "=== Accepted authentications (journal, last ${DAYS}) ==="
journalctl -u ssh -u sshd --since "$since" --no-pager -q 2>/dev/null \
  | grep -E "Accepted (password|publickey)" \
  | sed -E 's/^([A-Za-z0-9]+ [0-9]+ [0-9:]+).*Accepted (\S+) for (\S+) from ([0-9a-fA-F:.]+) port [0-9]+.*/\1 | \3@\4 | auth=\2/' \
  | tail -50

echo
echo "=== Failed logins (journal, last ${DAYS}) ==="
journalctl -u ssh -u sshd --since "$since" --no-pager -q 2>/dev/null \
  | grep -E "Failed (password|publickey)|Invalid user|Connection closed by authenticating" \
  | tail -30

echo
echo "=== Top source IPs (successful, journal window) ==="
journalctl -u ssh -u sshd --since "$since" --no-pager -q 2>/dev/null \
  | grep -oE "Accepted (password|publickey) for \S+ from [0-9a-fA-F:.]+" \
  | grep -oE "[0-9a-fA-F:.]+$" | sort | uniq -c | sort -rn

echo
echo "=== Top source IPs (failed) ==="
journalctl -u ssh -u sshd --since "$since" --no-pager -q 2>/dev/null \
  | grep -oE "from [0-9a-fA-F:.]+ port [0-9]+" | grep -oE "[0-9a-fA-F:.]+ port" \
  | sed 's/ port//' | sort | uniq -c | sort -rn | head -15
REMOTE
