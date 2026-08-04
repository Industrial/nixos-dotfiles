# Colocated suite: xserver enabled with xterm session.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {xterm = {outPath = "/xterm";};};
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "window-manager" {
    xserver = assay.eq mod.services.xserver.enable true;
  }
