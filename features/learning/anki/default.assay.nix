# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { anki = "anki"; "anki-bin" = "anki-bin"; "anki-sync-server" = "anki-sync-server"; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.environment.systemPackages)
'';
in
  assay.suite "anki" {
    systemPackages = assay.eq packages ''[ "anki" "anki-bin" "anki-sync-server" ]'';
  }
