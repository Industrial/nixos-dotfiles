# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { "signal-desktop" = "signal-desktop"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "signal-desktop" {
    systemPackages = assay.eq packages ''[ "signal-desktop" ]'';
  }
