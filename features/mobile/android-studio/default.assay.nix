# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    "android-studio" = "android-studio";
    "android-tools" = "android-tools";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "android-studio" {
    systemPackages = assay.eq mod.environment.systemPackages ["android-studio" "android-tools"];
  }
