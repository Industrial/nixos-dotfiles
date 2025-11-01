{
  settings,
  pkgs,
  lib,
  ...
}: let
  # Helper function to determine if we need sudo
  # Returns empty string if running as root, "sudo " otherwise
  sudoIfNeeded = pkgs.writeShellScript "sudo-if-needed" ''
    if [ "$EUID" -eq 0 ]; then
      # Already root, no sudo needed
      exec "$@"
    else
      # Not root, use sudo
      exec sudo "$@"
    fi
  '';

  # Systemd service wrapper script that runs update without requiring sudo
  # (since systemd service already runs as root)
  updateScript = pkgs.writeShellScript "nixos-auto-update" ''
    set -euo pipefail

    REPO_DIR="/home/${settings.username}/.dotfiles"
    HOSTNAME="${settings.hostname}"
    USERNAME="${settings.username}"

    cd "$REPO_DIR"

    echo "> update > system (running as root)"

    # Clear VSCode cache (user operation, but safe from root)
    if [ -f "$REPO_DIR/features/programming/vscode/bin/clear-cache" ]; then
      HOME="/home/$USERNAME" USER="$USERNAME" "$REPO_DIR/features/programming/vscode/bin/clear-cache" || true
    fi

    # Navigate to host directory
    cd "$REPO_DIR/hosts/$HOSTNAME"

    # Rebuild system (we're already root, so no sudo needed)
    echo "> nixos-rebuild switch --flake \".#$HOSTNAME\" --show-trace"
    nixos-rebuild switch --flake ".#$HOSTNAME" --show-trace --option eval-cache false

    cd "$REPO_DIR"

    # Update login shell (we're root, so chsh works directly)
    if [ -f "$REPO_DIR/bin/update/login-shell" ]; then
      echo "> update > login-shell"
      chsh -s /run/current-system/sw/bin/fish "$USERNAME" || true
    fi

    # Link configuration files (these run as the user, not root)
    # Use su to switch to user context for user-owned files
    if [ -f "$REPO_DIR/features/network/ladybird/bin/link-files-nixos" ]; then
      su - "$USERNAME" -c "cd $REPO_DIR && $REPO_DIR/features/network/ladybird/bin/link-files-nixos" || true
    fi

    if [ -f "$REPO_DIR/features/programming/vscode/bin/link-files-nixos" ]; then
      su - "$USERNAME" -c "cd $REPO_DIR && $REPO_DIR/features/programming/vscode/bin/link-files-nixos" || true
    fi

    if [ -f "$REPO_DIR/features/window-manager/dwm/bin/link-files-nixos" ]; then
      su - "$USERNAME" -c "cd $REPO_DIR && $REPO_DIR/features/window-manager/dwm/bin/link-files-nixos" || true
    fi

    if [ -f "$REPO_DIR/features/window-manager/river/bin/link-files-nixos" ]; then
      su - "$USERNAME" -c "cd $REPO_DIR && $REPO_DIR/features/window-manager/river/bin/link-files-nixos" || true
    fi

    echo "> update > system > complete"
  '';
in {
  # Automatic daily system update service
  # Rebuilds and switches to the latest flake configuration every 24 hours
  # Runs as root to avoid sudo requirements
  systemd.services.nixos-auto-update = {
    description = "Automatically rebuild and switch NixOS flake configuration";
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "oneshot";
      # Run as root to execute nixos-rebuild switch without sudo
      User = "root";
      # Ensure we're in the correct directory
      WorkingDirectory = "/home/${settings.username}/.dotfiles";
      # Use our wrapper script that doesn't require sudo
      ExecStart = "${updateScript}";
      # Don't kill the service if it takes longer than expected
      TimeoutStopSec = 0;
      # Logging
      StandardOutput = "journal";
      StandardError = "journal";
      # Security settings - allow necessary paths
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [
        "/home/${settings.username}/.dotfiles/logs"
        "/home/${settings.username}/.dotfiles/hosts/${settings.hostname}/flake.lock"
        "/home/${settings.username}/.config"
        "/home/${settings.username}/.cache"
        "/home/${settings.username}/.local"
        "/nix"
        "/run"
        "/var"
      ];
      # Allow switching users for user file operations
      SupplementaryGroups = ["${settings.username}"];
    };

    # Environment variables
    environment = {
      HOME = "/home/${settings.username}";
      USER = settings.username;
    };
  };

  # Timer that triggers the service daily
  systemd.timers.nixos-auto-update = {
    description = "Timer for automatic NixOS updates";
    wantedBy = ["timers.target"];

    timerConfig = {
      # Run daily at 2 AM
      OnCalendar = "02:00";
      # Also run if missed (if system was off)
      Persistent = true;
      # Add randomization to avoid thundering herd (0-1 hour delay)
      RandomizedDelaySec = "1h";
    };
  };
}
