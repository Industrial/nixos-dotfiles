#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
TARGET="$HERMES_HOME/plugins/hermes-cursor-harness"
CONFIG="$HERMES_HOME/cursor_harness.json"
PYTHON_BIN_RAW="${PYTHON:-$(command -v python3)}"
if [[ "$PYTHON_BIN_RAW" == */* ]]; then
  PYTHON_BIN="$(cd "$(dirname "$PYTHON_BIN_RAW")" && pwd)/$(basename "$PYTHON_BIN_RAW")"
else
  PYTHON_BIN="$(command -v "$PYTHON_BIN_RAW")"
fi

mkdir -p "$TARGET"
rm -rf "$TARGET/hermes_cursor_harness"
rm -rf "$TARGET/skills"
rm -rf "$TARGET/dashboard"
cp "$SRC_DIR/plugin.yaml" "$TARGET/plugin.yaml"
cp "$SRC_DIR/__init__.py" "$TARGET/__init__.py"
cp -R "$SRC_DIR/hermes_cursor_harness" "$TARGET/hermes_cursor_harness"
cp -R "$SRC_DIR/skills" "$TARGET/skills"
cp -R "$SRC_DIR/dashboard" "$TARGET/dashboard"

if ! "$PYTHON_BIN" -c 'import certifi' >/dev/null 2>&1; then
  echo "Installing certifi for $PYTHON_BIN so Cursor Background Agent HTTPS checks work..."
  "$PYTHON_BIN" -m pip install --user 'certifi>=2024.2.2'
fi

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/hermes-cursor-harness" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$TARGET:\${PYTHONPATH:-}"
exec "\${PYTHON:-$PYTHON_BIN}" -m hermes_cursor_harness.cli "\$@"
EOF
chmod +x "$HOME/.local/bin/hermes-cursor-harness"
cat > "$HOME/.local/bin/hermes-cursor-harness-mcp" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$TARGET:\${PYTHONPATH:-}"
exec "\${PYTHON:-$PYTHON_BIN}" -m hermes_cursor_harness.mcp_server "\$@"
EOF
chmod +x "$HOME/.local/bin/hermes-cursor-harness-mcp"

if [[ ! -f "$CONFIG" ]]; then
  cp "$SRC_DIR/examples/cursor_harness.json" "$CONFIG"
  echo "Created $CONFIG. Edit project aliases before first use."
fi

echo "Installed hermes-cursor-harness to $TARGET"
echo "Installed CLI wrapper to $HOME/.local/bin/hermes-cursor-harness"
echo "Installed MCP wrapper to $HOME/.local/bin/hermes-cursor-harness-mcp"
echo "Run: hermes-cursor-harness sdk install && hermes-cursor-harness sdk status"
echo "Optional API key: hermes-cursor-harness api-key set"
echo "Enable it in ~/.hermes/config.yaml under plugins.enabled and add cursor_harness to platform_toolsets."
