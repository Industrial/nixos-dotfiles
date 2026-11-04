# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {tokei = "tokei";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "tokei" {
    systemPackages = assay.eq mod.environment.systemPackages ["tokei"];
  }
