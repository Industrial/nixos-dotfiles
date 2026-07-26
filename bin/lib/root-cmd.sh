#!/usr/bin/env bash

# Run a command as root. Prefers cached/interactive sudo, then pkexec (polkit GUI).
root_cmd() {
    if sudo -n "$@" 2>/dev/null; then
        return 0
    fi

    if [ -t 0 ]; then
        sudo "$@"
        return $?
    fi

    if [ -n "${DISPLAY:-}" ] && command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
        return $?
    fi

    echo "root_cmd: root privileges required (try: sudo -v)" >&2
    return 1
}
