# Colocated suite: systemPackages lands nixfetch wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nixfetch";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nixfetch" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixfetch"];
  }
