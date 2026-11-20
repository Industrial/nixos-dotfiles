# Desktop notices for what an update is waiting on (docs/runbooks/updates.md):
#   * an open lock-bump PR from the update-flake-lock workflow, awaiting review;
#   * a reboot, when comin switched to a new kernel/initrd the host has not booted;
#   * otherwise, upstream inputs that moved since the last bump, with the exact
#     package diff (`nix store diff-closures`) when RAM allows building it.
# It never switches, merges or reboots anything: those stay with the operator.
{
  pkgs,
  inputs,
  settings,
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
    description = "Report pending NixOS updates: lock-bump PR, reboot, upstream changes";
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
      NIXOS_UPDATE_BOOTED = "/run/booted-system";
      # Public repo: the open-PR lookup needs no token. Branch matches
      # .github/workflows/update-flake-lock.yml.
      NIXOS_UPDATE_GITHUB_REPO = "Industrial/nixos-dotfiles";
      NIXOS_UPDATE_LOCK_BRANCH = "update/flake-lock";
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
