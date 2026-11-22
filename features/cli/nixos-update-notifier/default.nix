# Desktop notices for what an update is waiting on (docs/runbooks/updates.md):
#   * an open lock-bump PR from the update-flake-lock workflow, awaiting review;
#   * a reboot, when comin switched to a new kernel/initrd the host has not booted;
#   * otherwise, upstream inputs that moved since the last bump, with the exact
#     package diff (`vdiff --json`) when RAM allows building it.
# It never switches, merges or reboots anything: those stay with the operator.
#
# vdiff took over from `nix store diff-closures` (GH-207). Rollback:
#   features.cli.nixos-update-notifier.differ = "nix";
{
  config,
  lib,
  pkgs,
  settings,
  ...
}: let
  cfg = config.features.cli.nixos-update-notifier;
  notifierPkg = pkgs.callPackage ../../../rust/tools/nixos-update-notifier/default.nix {};
  flakeDir = "${settings.userdir}/.dotfiles";
in {
  options.features.cli.nixos-update-notifier.differ = lib.mkOption {
    type = lib.types.enum ["vdiff" "nix"];
    default = "vdiff";
    description = "Closure differ behind the notifier's package list: vdiff (`vdiff --json`), or nix (`nix store diff-closures`, the rollback).";
  };

  config = {
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
        # Public repo: the open-PR lookup needs no token. One GET of the open PRs,
        # filtered on head.ref: the branch itself (the workflow's single PR,
        # .github/workflows/update-flake-lock.yml LOCK_BRANCH) or vbump's per-input
        # `<branch>-<input>` (rust/tools/vbump, GH-200), from this repo, not a fork.
        NIXOS_UPDATE_GITHUB_REPO = "Industrial/nixos-dotfiles";
        NIXOS_UPDATE_LOCK_BRANCH = "update/flake-lock";
        NIXOS_UPDATE_DIFFER = cfg.differ;
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
  };
}
