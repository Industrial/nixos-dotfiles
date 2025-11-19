# GNOME Workspace Setup - Launch applications on specific workspaces
{
  pkgs,
  lib,
  config,
  settings,
  ...
}: {
  # Systemd user service for workspace launcher
  # This service launches applications at login and the auto-move-windows
  # extension will move them to their assigned workspaces
  systemd.user.services."gnome-workspace-launcher" = {
    description = "Launch applications on specific workspaces";
    after = ["graphical-session.target"];
    wants = ["graphical-session.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "workspace-launcher" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Wait for GNOME Shell to be ready
        # Check if GNOME Shell is running via D-Bus
        until gdbus call --session \
          --dest org.gnome.Shell \
          --object-path /org/gnome/Shell \
          --method org.gnome.Shell.Eval "true" > /dev/null 2>&1; do
          echo "Waiting for GNOME Shell to be ready..."
          sleep 0.5
        done

        echo "GNOME Shell is ready, launching applications..."

        # Wait a bit more for auto-move-windows extension to be ready
        sleep 2

        # Launch applications (they'll be moved to workspaces by auto-move-windows extension)
        # Applications will be moved based on the application-list configuration in dconf.nix

        # Launch Librewolf on workspace 1 (index 0) - will be moved by extension
        ${pkgs.librewolf}/bin/librewolf &

        # Launch VS Code/Cursor on workspace 2 (index 1) - will be moved by extension
        ${pkgs.cursor}/bin/cursor &

        # Launch Obsidian on workspace 4 (index 3) - will be moved by extension
        ${pkgs.obsidian}/bin/obsidian &

        # Launch Spotify on workspace 6 (index 5) - will be moved by extension
        ${pkgs.spotify}/bin/spotify &

        # Launch Discord on workspace 8 (index 7) - will be moved by extension
        ${pkgs.discord}/bin/discord &

        # Launch Discord on workspace 8 (index 7) - will be moved by extension
        ${pkgs.signal-desktop}/bin/signal-desktop &
      '';
    };

    wantedBy = ["graphical-session.target"];
  };
}
