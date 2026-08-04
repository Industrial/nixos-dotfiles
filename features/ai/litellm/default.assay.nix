# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {litellm = "litellm";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "litellm" {
    systemPackages = assay.eq mod.environment.systemPackages ["litellm"];
  }
