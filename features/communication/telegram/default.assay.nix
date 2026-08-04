# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { "telegram-desktop" = "telegram-desktop"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "telegram" {
    systemPackages = assay.eq packages ''[ "telegram-desktop" ]'';
  }
