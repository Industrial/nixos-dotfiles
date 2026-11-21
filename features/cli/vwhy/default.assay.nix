# Colocated suite for features/cli/vwhy: the package it installs is the
# rust/tools/vwhy crate, built from the pinned nixpkgs.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;

  # Stubbed pkgs: which package file the feature calls, and with what.
  stub = {callPackage = path: args: {inherit path args;};};
  stubbed = (import ./default.nix {pkgs = stub;}).environment.systemPackages;

  # The real module, evaluated.
  cfg = nixos.eval {modules = [./default.nix];};
  vwhys = builtins.filter (p: (p.pname or "") == "vwhy") cfg.environment.systemPackages;
in
  assay.suite "cli-vwhy" {
    installsTheCrate = assay.eq (map (p: p.path) stubbed) [../../../rust/tools/vwhy/default.nix];
    noOverrides = assay.eq (map (p: p.args) stubbed) [{}];

    inSystemPackages = assay.eq (builtins.length vwhys) 1;
    providesTheBinary = assay.eq (map (p: p.meta.mainProgram) vwhys) ["vwhy"];
  }
