# Colocated suite for features/nix/vfetch — vfetch serve as the first substituter.
#
# Evaluated against the real NixOS option tree through lib/features.nix's wrapper, so the
# rollback switch is the real one: `features.nix.vfetch.enable = lib.mkForce false` on a
# selection that enables it must leave nix.conf and systemd as if it had never been on.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../../../lib/features.nix {inherit lib;};

  evalWith = extra:
    nixos.eval {
      modules = [(features.feature ./default.nix) {features.nix.vfetch.enable = true;}] ++ extra;
      settings.hostname = "probe";
    };
  on = evalWith [];
  off = evalWith [{features.nix.vfetch.enable = lib.mkForce false;}];
  local = "http://127.0.0.1:5101";
  service = on.systemd.services.vfetch-serve;
in
  assay.suite "features-nix-vfetch" {
    # Take-over: every substitution on the host asks vfetch serve first.
    isTheFirstSubstituter = assay.eq (builtins.head on.nix.settings.substituters) local;
    # The real caches stay behind it, so Nix falls back to them by itself.
    keepsTheOtherSubstituters =
      assay.eq (builtins.any (s: lib.hasPrefix "https://cache.nixos.org" s) on.nix.settings.substituters) true;

    runsServeOnLocalhost =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-vfetch-[^/]+/bin/vfetch serve --listen 127.0.0.1:5101" service.serviceConfig.ExecStart != null) true;
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    restartsWhenItDies = assay.eq [service.serviceConfig.Restart service.serviceConfig.RestartSec] ["always" "2s"];
    sandboxed = assay.eq [service.serviceConfig.DynamicUser service.serviceConfig.ProtectSystem] [true "strict"];

    # Rollback: one switch drops the substituter and the service.
    rollbackDropsTheSubstituter = assay.eq (builtins.elem local off.nix.settings.substituters) false;
    rollbackStopsTheService = assay.eq (off.systemd.services ? vfetch-serve) false;
  }
