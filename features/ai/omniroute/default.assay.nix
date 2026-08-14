# Colocated suite: OmniRoute package + user service shape.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    lib = (import <nixpkgs> {}).lib;
    pkgs = {callPackage = path: args: "omniroute";};
    mod = import ./default.nix {
      inherit lib pkgs;
      config = {};
    };
  in
    mod;
in
  assay.suite "omniroute" {
    systemPackages = assay.eq mod.environment.systemPackages ["omniroute"];
    serviceWantedBy = assay.eq mod.systemd.user.services.omniroute.wantedBy ["default.target"];
  }
