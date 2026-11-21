# vopt takes over store deduplication from `auto-optimise-store`.
#
# With auto-optimise-store on (features/nixos/default.nix), the daemon NAR-hashes
# every file of every path it adds, inline, before the build or substitution
# returns. This switches that off and runs vopt (rust/tools/vopt, Voltaic) daily
# instead: it hard-links the files of every path registered since its last run
# into /nix/store/.links, in parallel, holding the GC lock shared so builds carry
# on and only a collection waits. Store paths are immutable, so a path linked
# once stays linked. Disable the feature to get inline optimisation back.
{
  lib,
  pkgs,
  ...
}: let
  vopt = pkgs.callPackage ../../../rust/tools/vopt {};
in {
  nix.settings.auto-optimise-store = lib.mkForce false;

  environment.systemPackages = [vopt];

  systemd.services.vopt = {
    description = "Nix store optimisation (vopt)";
    startAt = "daily";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe vopt} run";
      # /var/lib/vopt/last-id: the highest store id the last run saw.
      StateDirectory = "vopt";
      # Hashing is background work; builds keep running alongside it.
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.vopt.timerConfig.Persistent = true;
}
