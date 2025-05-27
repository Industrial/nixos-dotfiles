#!/usr/bin/env sh
# Script to build the dwm-status Nix derivation

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Navigate to the parent directory (rust/tools/dwm-status)
cd "$SCRIPT_DIR/.."

echo "Building dwm-status using Nix..."
nix-build default.nix

# The result will be a symlink named 'result' in the current directory (rust/tools/dwm-status)
# pointing to the actual build output in the Nix store.
echo "Build complete. The result is in ./result/bin/dwm-status"