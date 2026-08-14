# GNOME Workspace Setup - Launch applications on specific workspaces
{
  pkgs,
  lib,
  ...
}: let
  workspaceLauncher = pkgs.writeShellApplication {
    name = "workspace-launcher";
    runtimeInputs = with pkgs; [
      systemd
      gtk3
    ];
    text = ''
      set -euo pipefail

      # org.gnome.Shell appears on the session bus when the compositor is ready.
      # Shell.Eval returns false on GNOME 49+ and must not be used as a probe.
      deadline=$((SECONDS + 120))
      while ! busctl --user --timeout 2 status org.gnome.Shell >/dev/null 2>&1; do
        if (( SECONDS >= deadline )); then
          echo "Timed out waiting for org.gnome.Shell on session bus" >&2
          exit 1
        fi
        sleep 1
      done

      echo "GNOME Shell is ready, launching applications..."

      # Give auto-move-windows a moment to register window rules.
      sleep 2

      gtk-launch librewolf.desktop &
      gtk-launch cursor.desktop &
      gtk-launch obsidian.desktop &
      gtk-launch spotify.desktop &
      gtk-launch discord.desktop &
      gtk-launch signal-desktop.desktop &
    '';
  };
in {
  systemd.user.services."gnome-workspace-launcher" = {
    description = "Launch applications on specific workspaces";
    after = ["graphical-session.target"];
    wants = ["graphical-session.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "3min";
      ExecStart = lib.getExe workspaceLauncher;
    };

    wantedBy = ["graphical-session.target"];
  };
}
