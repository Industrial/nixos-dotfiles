# Assay: the nightly auto-update is switched OFF.
#
# The module defines a nightly `nix flake update && nixos-rebuild switch`, gated behind a
# hard-coded `enableAutoUpdate = false`: root cannot update a user-owned flake (libgit2
# "repository path is not owned by current user"), and a nightly switch fights interactive
# sessions for RAM. features/cli/nixos-update-notifier replaces it. These claims read the
# evaluated systemd units, so flipping the flag (or enabling the unit some other way from
# this file) fails here rather than surprising a host at 04:00.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./default.nix];};
in
  assay.suite "auto-update" {
    noUpdateService = assay.eq (cfg.systemd.services ? nixos-auto-update) false;
    noUpdateTimer = assay.eq (cfg.systemd.timers ? nixos-auto-update) false;
    # Nothing else sneaks in: the unit sets match an empty system's.
    addsNoServices =
      assay.eq (builtins.attrNames cfg.systemd.services) (builtins.attrNames nixos.baseline.systemd.services);
    addsNoTimers =
      assay.eq (builtins.attrNames cfg.systemd.timers) (builtins.attrNames nixos.baseline.systemd.timers);
  }
