# Colocated suite for hosts/huginn/configuration.nix — evaluated selection, not source text.
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
    # huginn is the Intel N200 tablet; the rest of the fleet is AMD.
    intelGraphics = assay.eq [(has "nixos.graphics.intel") (has "nixos.graphics.amd")] [true false];
    noAi = assay.eq cfg.profiles.ai.enable false;
    noGaming = assay.eq cfg.profiles.gaming.enable false;
  }
