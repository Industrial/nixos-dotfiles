# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { "gemini-cli" = "gemini-cli"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "gemini-cli" {
    systemPackages = assay.eq packages ''[ "gemini-cli" ]'';
  }
