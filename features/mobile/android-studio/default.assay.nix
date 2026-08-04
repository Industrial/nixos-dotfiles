# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "android-studio" = "android-studio"; "android-tools" = "android-tools"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "android-studio" {
    systemPackages = assay.eq packages ''[ "android-studio" "android-tools" ]'';
  }
