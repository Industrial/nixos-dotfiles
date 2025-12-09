# Desktop Profile
# Desktop environment and window managers
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ./base.nix

    # Window Manager
    ../features/nixos/window-manager
    ../features/window-manager/alacritty
    ../features/window-manager/kitty
    #../features/window-manager/ghostty
    ../features/window-manager/gnome
    ../features/window-manager/hyprland
    #../features/window-manager/slock
    inputs.stylix.nixosModules.stylix
    ../features/window-manager/stylix
    ../features/window-manager/xclip
    # ../features/window-manager/xfce
    ../features/window-manager/xsel
  ];
}
