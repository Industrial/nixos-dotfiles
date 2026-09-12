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
    ../features/nixos/window-manager
    ../features/window-manager/alacritty
    ../features/window-manager/gnome
    ../features/window-manager/hyprland
    ../features/window-manager/stylix
    ../features/window-manager/xclip
    ../features/window-manager/xfce-screenshooter
    ../features/window-manager/xsel
    inputs.stylix.nixosModules.stylix
  ];
}
