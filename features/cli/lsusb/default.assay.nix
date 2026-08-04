# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { usbutils = "usbutils"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "lsusb" {
    systemPackages = assay.eq mod.environment.systemPackages [ "usbutils" ];
  }
