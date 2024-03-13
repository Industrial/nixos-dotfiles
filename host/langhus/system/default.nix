{
  settings,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./graphics
    ./hardware-configuration.nix

    # Lab
    ../../../features/lab/media/invidious
    ../../../features/lab/monitoring/grafana
    ../../../features/lab/monitoring/prometheus
    ../../../features/lab/documents/cryptpad
    ../../../features/lab/passwords/vaultwarden
    ../../../features/lab/proxy/nginx

    # CLI
    ../../../features/system/cli/bat
    ../../../features/system/cli/btop
    ../../../features/system/cli/direnv
    ../../../features/system/cli/e2fsprogs
    ../../../features/system/cli/eza
    ../../../features/system/cli/fd
    ../../../features/system/cli/fish
    ../../../features/system/cli/fzf
    ../../../features/system/cli/gh
    ../../../features/system/cli/neofetch
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/ranger
    ../../../features/system/cli/ripgrep
    ../../../features/system/cli/unrar
    ../../../features/system/cli/unzip

    # Communication
    ../../../features/system/communication/discord

    # Crypto
    ../../../features/system/crypto/monero

    # Filesystems
    ../../../features/system/filesystems/gparted

    # Finance
    ../../../features/system/finance/homebank

    # Hardware
    ../../../features/system/hardware/zsa-keyboard

    # Network
    ../../../features/system/network/syncthing

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/shell

    # NixOS
    ../../../features/system/nixos/bluetooth
    ../../../features/system/nixos/boot
    ../../../features/system/nixos/console
    ../../../features/system/nixos/docker
    ../../../features/system/nixos/fonts
    ../../../features/system/nixos/i18n
    ../../../features/system/nixos/networking
    ../../../features/system/nixos/nix
    ../../../features/system/nixos/printing
    ../../../features/system/nixos/security
    # ../../../features/system/nixos/security/apparmor
    #../../../features/system/nixos/security/clamav
    ../../../features/system/nixos/security/yubikey
    ../../../features/system/nixos/sound
    ../../../features/system/nixos/system
    ../../../features/system/nixos/time
    ../../../features/system/nixos/users
    ../../../features/system/nixos/window-manager
    inputs.microvm.nixosModules.host

    # Programming
    ../../../features/system/programming/ollama

    # # Window Manager
    # ../../../features/system/window-manager/xfce
  ];
}
