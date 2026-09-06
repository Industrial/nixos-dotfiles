#!/usr/bin/env bash
# Random wallpaper switcher for awww
# Usage: awww-random.sh [directory]
# Defaults to /mnt/mimir/Images/Wallpapers/space

WALLPAPER_DIR="${1:-/mnt/mimir/Images/Wallpapers/space}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "Wallpaper directory not found: $WALLPAPER_DIR" >&2
    exit 1
fi

# Get random wallpaper
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)

if [[ -z "$WALLPAPER" ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Set wallpaper with transition
awww img "$WALLPAPER" --transition-type grow --transition-pos center --transition-duration 1
