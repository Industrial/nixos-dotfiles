#!/usr/bin/env bash
# Dev runner for skjold - builds and runs with proper library paths
# Usage: ./run-dev.sh [--build]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$WORKSPACE_ROOT/target/release/skjold"

# Build if requested or binary doesn't exist
if [[ "${1:-}" == "--build" ]] || [[ ! -x "$BINARY" ]]; then
    echo "Building skjold..." >&2
    cd "$WORKSPACE_ROOT"
    cargo build --release -p skjold
fi

# Library paths for Iced/Wayland runtime deps
# Try to extract from nix-built skjold with wayland in rpath, else use fallback
WAYLAND_LIBS=""
NIX_SKJOLD=$(command -v skjold 2>/dev/null || echo "")
if [[ -n "$NIX_SKJOLD" ]] && command -v patchelf &>/dev/null; then
    RPATH=$(patchelf --print-rpath "$(readlink -f "$NIX_SKJOLD")" 2>/dev/null || echo "")
    if [[ "$RPATH" == *wayland* ]]; then
        WAYLAND_LIBS="$RPATH"
    fi
fi

# Fallback: use known paths (from nix-built skjold with postFixup)
if [[ -z "$WAYLAND_LIBS" ]]; then
    WAYLAND_LIBS="/nix/store/vjcwhp0milwa1jqy1inpjxrsh8hjrgwc-wayland-1.26.0/lib:/nix/store/yk95z4hjlzdk418px0fc797qszccfj5p-libxkbcommon-1.13.2/lib:/nix/store/lk4614327cn1h9z3m6cvnls95n13m1cj-vulkan-loader-1.4.357.0/lib:/nix/store/rarvfpm927fcbd6b9p0crg09w9r3ywb3-libglvnd-1.7.0/lib"
fi

export LD_LIBRARY_PATH="${WAYLAND_LIBS}:${LD_LIBRARY_PATH:-}"

exec "$BINARY" "$@"
