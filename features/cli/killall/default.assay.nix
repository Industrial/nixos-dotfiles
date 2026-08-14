# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {killall = "killall";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "killall" {
    systemPackages = assay.eq mod.environment.systemPackages ["killall"];
  }
