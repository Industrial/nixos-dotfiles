# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { weechat = "weechat"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "weechat" {
    systemPackages = assay.eq mod.environment.systemPackages [ "weechat" ];
  }
