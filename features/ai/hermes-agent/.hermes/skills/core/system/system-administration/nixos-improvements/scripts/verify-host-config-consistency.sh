#!/usr/bin/env bash
# Verification script for checking host flake.nix consistency
# Usage: ./verify-host-config-consistency.sh [host1] [host2] ...

set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"
HOSTS_DIR="$DOTFILES_ROOT/hosts"

if [ $# -eq 0 ]; then
    # Default to all hosts if none specified
    HOSTS=("huginn" "mimir" "drakkar")
else
    HOSTS=("$@")
fi

echo "Verifying host flake.nix consistency..."
echo "======================================"

# Function to extract normalized feature keys from a flake.nix
extract_feature_keys() {
    local flake_path="$1"
    if [ ! -f "$flake_path" ]; then
        echo "Error: Flake file not found: $flake_path" >&2
        return 1
    fi
    
    # Extract lines between modules = [ and ];
    awk '/modules = \[/,/];/' "$flake_path" | \
    # Remove the brackets lines
    sed '1d;$d' | \
    # Process each line: strip whitespace, remove leading # and whitespace after
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
    # Remove empty lines and comments-only lines
    grep -v '^$' | sed 's/^#//' | \
    # Remove leading whitespace that might remain after comment removal
    sed 's/^[[:space:]]*//'
}

# Get keys from first host as reference
if [ ${#HOSTS[@]} -eq 0 ]; then
    echo "Error: No hosts specified" >&2
    exit 1
fi

REFERENCE_HOST="${HOSTS[0]}"
REFERENCE_KEYS=$(extract_feature_keys "$HOSTS_DIR/$REFERENCE_HOST/flake.nix")
REFERENCE_EXIT_CODE=$?

if [ $REFERENCE_EXIT_CODE -ne 0 ]; then
    exit $REFERENCE_EXIT_CODE
fi

echo "Reference host: $REFERENCE_HOST"
echo "Reference feature count: $(echo "$REFERENCE_KEYS" | wc -l)"
echo

ALL_PASS=true

# Check each host against reference
for host in "${HOSTS[@]}"; do
    if [ "$host" = "$REFERENCE_HOST" ]; then
        echo "✓ $host: Reference host"
        continue
    fi
    
    HOST_KEYS=$(extract_feature_keys "$HOSTS_DIR/$host/flake.nix")
    HOST_EXIT_CODE=$?
    
    if [ $HOST_EXIT_CODE -ne 0 ]; then
        ALL_PASS=false
        continue
    fi
    
    if [ "$REFERENCE_KEYS" = "$HOST_KEYS" ]; then
        echo "✓ $host: Feature lists match"
    else
        echo "✗ $host: Feature lists differ"
        echo "  Differences:"
        diff -u <(echo "$REFERENCE_KEYS") <(echo "$HOST_KEYS") || true
        ALL_PASS=false
    fi
done

echo
if $ALL_PASS; then
    echo "✓ All hosts have consistent feature lists"
    exit 0
else
    echo "✗ Host feature lists are inconsistent"
    exit 1
fi