# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
    let
      pkgs = { fzf = "fzf"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages
  '';
in
  assay.suite "fzf" {
    systemPackages = assay.eq packages ''[ "fzf" ]'';
  }
