{
  pkgs,
  inputs,
  settings,
  lib,
  ...
}: let
  notifierPkg = pkgs.callPackage inputs.nixos-update-notifier-src {};
  flakeDir = "${settings.userdir}/.dotfiles";
in {
  environment.systemPackages = [
    notifierPkg
  ];

  # User timer so notifications hit the session D-Bus (GNOME banner + tray).
  systemd.user.services.nixos-update-notifier = {
    description = "Check for NixOS flake updates and notify with package list";
    after = ["graphical-session.target"];
    wants = ["graphical-session.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${notifierPkg}/bin/nixos-update-notifier";
      # Nice + IO scheduling: building the closure is heavy; don't fight interactive use.
      Nice = 10;
      IOSchedulingClass = "idle";
    };

    environment = {
      NIXOS_UPDATE_FLAKE = flakeDir;
      NIXOS_UPDATE_HOSTNAME = settings.hostname;
      NIXOS_UPDATE_CURRENT = "/run/current-system";
    };
  };

  systemd.user.timers.nixos-update-notifier = {
    description = "Daily NixOS update check with package-level notification";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
