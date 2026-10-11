#!/bin/bash
# Shared config loader. Source this from every script:
#   source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

_cfg_err() { echo "ERROR: $*" >&2; exit 1; }

_load_config() {
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [[ ! -f "$root/env.sh" ]]; then
        _cfg_err "env.sh not found. Run: cp $root/env.sh.example $root/env.sh and fill it in."
    fi
    # shellcheck disable=SC1091
    source "$root/env.sh"
    : "${REMOTE_HOST:?REMOTE_HOST not set in env.sh}"
    : "${WOL_MAC:?WOL_MAC not set in env.sh}"
    # Same machine, Ubuntu install; falls back to the Windows alias.
    : "${UBUNTU_HOST:=$REMOTE_HOST}"
}

# Remote is Windows by default: output is CRLF (+ non-UTF8 locale bytes).
# LC_ALL=C keeps tr byte-wise (BSD tr aborts on invalid UTF-8 otherwise).
win() { ssh "$REMOTE_HOST" "$1" | LC_ALL=C tr -d '\r'; }
