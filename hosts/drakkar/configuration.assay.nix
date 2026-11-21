# Colocated suite for hosts/drakkar/configuration.nix — evaluated selection, not source text.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  features = import ../../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {
    modules = [
      ./configuration.nix
      {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
    ];
  };
  has = f: builtins.elem f (features.enabledFeatures cfg);
in
  assay.suite "configuration" {
    enablesFleetAccess = assay.eq (has "fleet.remote-access") true;
    enablesGaming = assay.eq cfg.profiles.gaming.enable true;
    enablesAi = assay.eq cfg.profiles.ai.enable true;
    servesBuilds = assay.eq (has "fleet.nix-remote-builder-server") true;
    servesTheBinaryCache = assay.eq (has "nix.vcache") true;
    verifiesTheStore = assay.eq (has "nix.vverify") true;
    vbuildIsTheBuildHook = assay.eq (has "fleet.vbuild") true;
    # bin/update/flake runs vbump here; without it, it falls back to `nix flake update`.
    bumpsLocksPerInput = assay.eq (has "cli.vbump") true;
    amdGraphics = assay.eq [(has "nixos.graphics.amd") (has "nixos.graphics.intel")] [true false];
    noStigBaseSafe = assay.eq (has "security.stig.profiles.base-safe") false;
  }
