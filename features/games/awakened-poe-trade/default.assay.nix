# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "awakened-poe-trade" = "awakened-poe-trade"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "awakened-poe-trade" {
    systemPackages = assay.eq packages ''[ "awakened-poe-trade" ]'';
  }
