# Colocated suite: systemPackages and pager session variables from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {bat = "bat";};
  mod = import ./default.nix {inherit pkgs;};
  env = mod.environment.sessionVariables;
in
  assay.suite "bat" {
    systemPackages = assay.eq mod.environment.systemPackages ["bat"];
    manpager = assay.eq env.MANPAGER "bat -l man -p";
    pager = assay.eq env.PAGER "bat -p";
    theme = assay.eq env.BAT_THEME "ansi";
  }
