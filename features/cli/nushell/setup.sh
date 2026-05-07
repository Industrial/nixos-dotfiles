#!/usr/bin/env bash
# Nushell Setup Script
# Links configuration files to ~/.config/nushell/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/nushell"

echo "🐚 Setting up Nushell configuration..."

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "📁 Creating $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Backup existing configs if they exist and aren't symlinks
for file in env.nu config.nu; do
    if [ -f "$CONFIG_DIR/$file" ] && [ ! -L "$CONFIG_DIR/$file" ]; then
        echo "💾 Backing up existing $file to $file.backup"
        mv "$CONFIG_DIR/$file" "$CONFIG_DIR/$file.backup"
    fi
done

# Create symlinks
echo "🔗 Creating symlinks..."
ln -sf "$SCRIPT_DIR/env.nu" "$CONFIG_DIR/env.nu"
ln -sf "$SCRIPT_DIR/config.nu" "$CONFIG_DIR/config.nu"

echo ""
echo "✅ Nushell setup complete!"
echo ""
echo "📚 Quick Start:"
echo "   1. Type 'nu' to launch Nushell"
echo "   2. Try: l, g status, c ~/projects"
echo "   3. Data processing: ls | where size > 1MB"
echo "   4. Type 'exit' to return to Fish"
echo ""
echo "📖 See ~/.dotfiles/features/cli/nushell/README.md for more info"
echo ""
