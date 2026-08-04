# Colocated suite: XFCE desktop manager enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (let
      pkgs = {
        pinentry-qt = "pinentry-qt";
        wmctrl = "wmctrl";
        xarchiver = "xarchiver";
        xfce = { };
        xorg = { xwininfo = "xwininfo"; };
      };
    in import ${modFile} { inherit pkgs; })
  '';
in
  assay.suite "xfce" {
    xfceEnable = assay.eq "${mod}.services.xserver.desktopManager.xfce.enable" "true";
  }
