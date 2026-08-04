# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {zotero = "zotero";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "zotero" {
    systemPackages = assay.eq mod.environment.systemPackages ["zotero"];
  }
