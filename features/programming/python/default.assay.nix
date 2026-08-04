# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { python312 = "python312"; uv = "uv"; pipx = "pipx"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "python" {
    systemPackages = assay.eq packages ''[ "python312" "uv" "pipx" ]'';
  }
