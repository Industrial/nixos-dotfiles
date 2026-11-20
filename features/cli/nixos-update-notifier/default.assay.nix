# Colocated suite for features/cli/nixos-update-notifier.
#
# Evaluated against the real NixOS option tree with the nixos-update-notifier-src input resolved
# from flake.lock (rust/tools/nixos-update-notifier). The notifier draws a desktop notification,
# so — unlike atuin's maintenance timer — it is the one user unit here that
# does want and follow the graphical session.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;

  cfg = nixos.eval {
    modules = [./default.nix];
    settings = {
      hostname = "probe";
      userdir = "/home/alice";
    };
  };
  service = cfg.systemd.user.services.nixos-update-notifier;
  timer = cfg.systemd.user.timers.nixos-update-notifier;
in
  assay.suite "features-cli-nixos-update-notifier" {
    installsTheNotifier = assay.eq (nixos.hasPackage cfg "nixos-update-notifier") true;

    # A user unit so notifications reach the session D-Bus.
    hasUserTimer = assay.eq (cfg.systemd.user.timers ? nixos-update-notifier) true;
    serviceIsOneshot = assay.eq service.serviceConfig.Type "oneshot";
    runsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-nixos-update-notifier-[^/]+/bin/nixos-update-notifier" service.serviceConfig.ExecStart != null) true;
    followsTheGraphicalSession =
      assay.eq [service.wants service.after] [["graphical-session.target"] ["graphical-session.target"]];

    # The flake it checks is the user's checkout, for this host.
    checksTheUsersCheckout = assay.eq service.environment.NIXOS_UPDATE_FLAKE "/home/alice/.dotfiles";
    checksThisHost = assay.eq service.environment.NIXOS_UPDATE_HOSTNAME "probe";
    comparesAgainstTheRunningSystem = assay.eq service.environment.NIXOS_UPDATE_CURRENT "/run/current-system";
    # Building the closure is heavy; it must not fight interactive use.
    runsAtLowPriority = assay.eq [service.serviceConfig.Nice service.serviceConfig.IOSchedulingClass] [10 "idle"];

    timerIsWanted = assay.eq timer.wantedBy ["timers.target"];
    timerIsDailyAtNine = assay.eq timer.timerConfig.OnCalendar "*-*-* 09:00:00";
    timerCatchesUp = assay.eq timer.timerConfig.Persistent true;
  }
