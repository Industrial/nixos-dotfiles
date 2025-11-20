#!/usr/bin/env bash

chromium &
librewolf &
obsidian &
spotify &
discord &

# Notification Daemon
dunst &

# Compositor
picom &

# Polkit Authentication Agent (for GUI sudo prompts)
# Required for GUI applications that need elevated permissions
if [ -n "$DISPLAY" ]; then
    /run/current-system/sw/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
fi

# GNOME Keyring Daemon (for browser password storage)
# Required for browsers to store passwords securely
/run/current-system/sw/bin/gnome-keyring-daemon --start --components=ssh &
