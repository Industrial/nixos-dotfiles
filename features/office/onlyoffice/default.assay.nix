# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {onlyoffice-desktopeditors = "onlyoffice-desktopeditors";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "onlyoffice" {
    systemPackages = assay.eq mod.environment.systemPackages ["onlyoffice-desktopeditors"];
  }
