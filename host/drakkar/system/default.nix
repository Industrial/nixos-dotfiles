{pkgs, ...}: {
  imports = [
    ./graphics
    # TODO: Include this on the drakkar system and commit it.
    # ./hardware-configuration.nix

    # CLI
    ../../../features/system/cli/fish
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/starship
    ../../../features/system/cli/unrar

    # Network
    ../../../features/system/network/syncthing
    # ../../../features/system/network/tor

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/shell

    # Operating System
    ../../../features/system/nixos/bluetooth
    ../../../features/system/nixos/boot
    ../../../features/system/nixos/console
    ../../../features/system/nixos/docker
    ../../../features/system/nixos/fonts
    ../../../features/system/nixos/i18n
    ../../../features/system/nixos/lutris
    ../../../features/system/nixos/networking
    ../../../features/system/nixos/nix
    ../../../features/system/nixos/printing
    ../../../features/system/nixos/sound
    ../../../features/system/nixos/system
    ../../../features/system/nixos/time
    ../../../features/system/nixos/users
    ../../../features/system/nixos/window-manager

    # Programming
    ../../../features/system/programming/git
    # ../../../features/system/programming/haskell.nix

    # Window Manager
    ../../../features/system/window-manager/chromium
    # ../../../features/system/window-manager/hyprland
    ../../../features/system/window-manager/xfce
  ];
}