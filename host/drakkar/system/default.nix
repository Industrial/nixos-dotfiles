{pkgs, ...}: {
  imports = [
    ./graphics
    ./hardware-configuration.nix

    # CLI
    ../../../features/system/cli/fish
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/starship
    ../../../features/system/cli/unrar

    # Network
    ../../../features/system/network/syncthing
    # ../../../features/system/network/tor

    # Operating System
    ../../../features/system/operating-system/bluetooth
    ../../../features/system/operating-system/boot
    ../../../features/system/operating-system/console
    ../../../features/system/operating-system/fonts
    ../../../features/system/operating-system/home-manager
    ../../../features/system/operating-system/i18n
    ../../../features/system/operating-system/lutris
    ../../../features/system/operating-system/networking
    ../../../features/system/operating-system/nix
    ../../../features/system/operating-system/printing
    ../../../features/system/operating-system/shell
    ../../../features/system/operating-system/sound
    ../../../features/system/operating-system/system
    ../../../features/system/operating-system/time
    ../../../features/system/operating-system/users
    ../../../features/system/operating-system/window-manager

    # Programming
    ../../../features/system/programming/docker
    ../../../features/system/programming/git
    # ../../../features/system/programming/haskell.nix

    # Window Manager
    ../../../features/system/window-manager/chromium
    # ../../../features/system/window-manager/hyprland
    ../../../features/system/window-manager/xfce
  ];
}
