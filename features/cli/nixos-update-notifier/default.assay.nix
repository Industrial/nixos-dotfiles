# Colocated suite for features/cli/nixos-update-notifier.
#
# Evaluated against the real NixOS option tree. The notifier is the rust/tools/nixos-update-notifier
# crate, callPackage'd from the checkout like the other crates (no flake input since GH-207). It
# draws a desktop notification, so — unlike atuin's maintenance timer — it is the one user unit
# here that does want and follow the graphical session.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  settings = {
    hostname = "probe";
    userdir = "/home/alice";
  };
  cfg = nixos.eval {
    modules = [./default.nix];
    inherit settings;
  };
  # The rollback: `nix store diff-closures` instead of vdiff.
  rolledBack = nixos.eval {
    modules = [./default.nix {features.cli.nixos-update-notifier.differ = "nix";}];
    inherit settings;
  };
  service = cfg.systemd.user.services.nixos-update-notifier;
  timer = cfg.systemd.user.timers.nixos-update-notifier;
  notifiers = builtins.filter (p: (p.pname or "") == "nixos-update-notifier") cfg.environment.systemPackages;
  notifier = builtins.head notifiers;

  # Stubbed pkgs: which package file the feature calls, and with what.
  stub = {callPackage = path: args: {inherit path args;};};
  stubbed =
    (import ./default.nix {
      pkgs = stub;
      inherit lib settings;
      config.features.cli.nixos-update-notifier.differ = "vdiff";
    }).config.environment.systemPackages;

  # The lock branch the bump workflow uses, read from the workflow so the two cannot drift.
  workflow = builtins.readFile ./../../../.github/workflows/update-flake-lock.yml;
in
  assay.suite "features-cli-nixos-update-notifier" {
    installsTheNotifier = assay.eq (nixos.hasPackage cfg "nixos-update-notifier") true;
    # Built from the crate in this checkout with callPackage, not from a flake input.
    installsTheCrate = assay.eq (map (p: p.path) stubbed) [../../../rust/tools/nixos-update-notifier/default.nix];
    noOverrides = assay.eq (map (p: p.args) stubbed) [{}];
    installedOnce = assay.eq (builtins.length notifiers) 1;

    # vdiff took over from `nix store diff-closures` (GH-207): the default differ, run from its
    # absolute store path (the wrapper's NIXOS_UPDATE_VDIFF), with nothing to opt into.
    diffsWithVdiffByDefault = assay.eq service.environment.NIXOS_UPDATE_DIFFER "vdiff";
    vdiffIsAnAbsoluteStorePath =
      assay.eq (lib.hasInfix (builtins.unsafeDiscardStringContext "--set-default NIXOS_UPDATE_VDIFF ${lib.getExe notifier.passthru.vdiff}") notifier.postInstall) true;
    vdiffIsTheFleetsVdiff = assay.eq notifier.passthru.vdiff.pname "vdiff";
    # One option rolls back to Nix's own differ.
    nixDifferIsTheRollback =
      assay.eq rolledBack.systemd.user.services.nixos-update-notifier.environment.NIXOS_UPDATE_DIFFER "nix";

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
    # A pending reboot is the running system differing from the booted one.
    comparesAgainstTheBootedSystem = assay.eq service.environment.NIXOS_UPDATE_BOOTED "/run/booted-system";
    # Open lock-bump PRs are looked up on this (public) repo, on the workflow's branch.
    reportsOpenLockPrs = assay.eq service.environment.NIXOS_UPDATE_GITHUB_REPO "Industrial/nixos-dotfiles";
    lockBranchMatchesTheWorkflow =
      assay.eq (builtins.match ".*LOCK_BRANCH: ${service.environment.NIXOS_UPDATE_LOCK_BRANCH}\n.*" workflow != null) true;
    # Building the closure is heavy; it must not fight interactive use.
    runsAtLowPriority = assay.eq [service.serviceConfig.Nice service.serviceConfig.IOSchedulingClass] [10 "idle"];

    timerIsWanted = assay.eq timer.wantedBy ["timers.target"];
    timerIsDailyAtNine = assay.eq timer.timerConfig.OnCalendar "*-*-* 09:00:00";
    timerCatchesUp = assay.eq timer.timerConfig.Persistent true;
  }
