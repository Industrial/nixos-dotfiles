# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { gimp = "gimp"; "gimp-with-plugins" = "gimp-with-plugins"; gimpPlugins = { gmic = "gimpPlugins.gmic"; lightning = "gimpPlugins.lightning"; }; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "gimp" {
    systemPackages = assay.eq packages ''[ "gimp" "gimp-with-plugins" "gimpPlugins.gmic" "gimpPlugins.lightning" ]'';
  }
