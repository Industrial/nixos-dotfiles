# Colocated suite: CPU and disk scheduling, evaluated against the real NixOS option tree.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {modules = [./default.nix];};
  udevLines = lib.filter (l: l != "") (lib.splitString "\n" cfg.services.udev.extraRules);
  nvmeRule = lib.findFirst (lib.hasInfix "KERNEL==\"nvme") null udevLines;
in
  assay.suite "hardware" {
    performanceGovernor = assay.eq cfg.powerManagement.cpuFreqGovernor "performance";

    # hardware.graphics belongs to features/nixos/graphics; declaring it here too was a
    # duplicate definition. Only the module's own value matters, so read it raw.
    graphicsNotDeclaredHere =
      assay.eq ((import ./default.nix {
        inherit lib;
        config = {};
        pkgs = {};
      })
      .hardware
      ? graphics)
      false;

    # BFQ is what makes ionice classes and cgroup io weights mean anything on NVMe, which is
    # how `lowprio` keeps a build's I/O behind the desktop's.
    bfqModuleLoaded = assay.eq (builtins.elem "bfq" cfg.boot.kernelModules) true;
    nvmeGetsBfq = assay.eq (nvmeRule != null && lib.hasInfix "ATTR{queue/scheduler}=\"bfq\"" nvmeRule) true;
    # Only non-rotational NVMe namespaces; HDDs (mimir's RAID, drakkar's /data) keep the
    # kernel default.
    onlyNonRotational = assay.eq (nvmeRule != null && lib.hasInfix "ATTR{queue/rotational}==\"0\"" nvmeRule) true;
    oneSchedulerRule = assay.eq (lib.length (lib.filter (lib.hasInfix "queue/scheduler") udevLines)) 1;
  }
