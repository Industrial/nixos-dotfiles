# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    gimp = "gimp";
    "gimp-with-plugins" = "gimp-with-plugins";
    gimpPlugins = {
      gmic = "gimpPlugins.gmic";
      lightning = "gimpPlugins.lightning";
    };
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "gimp" {
    systemPackages = assay.eq mod.environment.systemPackages ["gimp" "gimp-with-plugins" "gimpPlugins.gmic" "gimpPlugins.lightning"];
  }
