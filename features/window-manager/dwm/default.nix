# DWM is a window manager.
{pkgs, ...}: let
  dwmOverlay = import ./overlays/my-dwm.nix {inherit pkgs;};
  # overlayedPkgs = import pkgs {overlays = [dwmOverlay];};
in {
  nixpkgs.overlays = [dwmOverlay];

  environment.systemPackages = with pkgs; [
    slock
    dmenu
    dunst
    # my-dwm
    picom
  ];

  #home.file.".xinitrc".source = ./.xinitrc;
  home.file."dwm/autostart.sh".source = ./autostart.sh;
  home.file."dwm/autostart_blocking.sh".source = ./autostart_blocking.sh;
}
