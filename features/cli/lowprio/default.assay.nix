# Colocated suite: lowprio, the wrapper that keeps heavy jobs behind the desktop.
#
# Claims read the module evaluated against the real NixOS option tree. The scope properties
# are carried on the package as passthru, so they are checked as data rather than by reading
# the script's text.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [./default.nix];
    settings = {
      username = "alice";
      userdir = "/home/alice";
    };
  };
  pkg = lib.findFirst (p: (p.name or "") == "lowprio") null cfg.environment.systemPackages;
  props = pkg.scopeProperties or [];
in
  assay.suite "lowprio" {
    installed = assay.eq (pkg != null) true;
    hasMainProgram = assay.eq (pkg.meta.mainProgram or null) "lowprio";

    # Low I/O and CPU weight: the desktop's work wins under contention.
    lowIoWeight = assay.eq (builtins.elem "IOWeight=10" props) true;
    lowCpuWeight = assay.eq (builtins.elem "CPUWeight=20" props) true;
    # Throttle before the cap, and the cap below the host-wide oomkiller (90%), so a runaway
    # job dies inside its own scope instead of costing the session a victim.
    memoryThrottledFirst = assay.eq (builtins.elem "MemoryHigh=70%" props) true;
    memoryCappedBelowOomkiller = assay.eq (builtins.elem "MemoryMax=85%" props) true;

    # sccache's cache gets NOCOW when it exists, and nothing creates ~/.cache as root.
    sccacheNocow = assay.eq (builtins.elem "h /home/alice/.cache/sccache - - - - +C" cfg.systemd.tmpfiles.rules) true;
    noRootOwnedCacheDir = assay.eq (lib.filter (r: lib.hasPrefix "d /home/alice/.cache" r) cfg.systemd.tmpfiles.rules) [];
  }
