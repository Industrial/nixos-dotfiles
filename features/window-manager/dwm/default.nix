# DWM is a window manager.
{pkgs, ...}: let
  dwmOverlay = import ./overlays/my-dwm.nix {inherit pkgs;};
  # overlayedPkgs = import pkgs {overlays = [dwmOverlay];};
in {
  nixpkgs.overlays = [dwmOverlay];

  environment.systemPackages = with pkgs; [
    # DWM
    my-dwm

    # Screen Lock
    slock

    # Ctrl-p Menu
    dmenu

    # TODO: ???
    dunst

    # TODO: ???
    picom
  ];

  services = {
    xserver = {
      displayManager = {
        session = [
          {
            manage = "desktop";
            name = "dwm";
            start = ''
              ${pkgs.my-dwm}/bin/dwm
            '';
          }
        ];
      };
    };
  };
}
