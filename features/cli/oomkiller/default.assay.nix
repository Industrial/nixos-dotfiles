# Colocated suite for features/cli/oomkiller/default.nix — the oomkiller daemon as a system
# service, built from the oomkiller-src input (rust/tools/oomkiller) resolved from flake.lock.
#
# A memory guard that is not running is no guard: the claims pin that it starts at boot, comes
# back when it dies, and runs the binary this feature installs.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;

  cfg = nixos.eval {
    modules = [./default.nix];
    settings.username = "alice";
  };
  service = cfg.systemd.services.oomkiller;
in
  assay.suite "oomkiller" {
    installsTheDaemon = assay.eq (nixos.hasPackage cfg "rust_oomkiller") true;

    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    runsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-rust_oomkiller-[^/]+/bin/oomkiller" service.serviceConfig.ExecStart != null) true;
    isALongRunningService = assay.eq service.serviceConfig.Type "simple";
    restartsWhenItDies = assay.eq [service.serviceConfig.Restart service.serviceConfig.RestartSec] ["always" "5s"];
    runsAsTheConfiguredUser = assay.eq service.serviceConfig.User "alice";
  }
