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

    # Games
    ../../../features/system/games/path-of-building
    ../../../features/system/games/steam

    # Hardware
    ../../../features/system/hardware/zsa-keyboard

    # Media
    ../../../features/system/media/lxqt-pavucontrol-qt
    ../../../features/system/media/lxqt-screengrab
    ../../../features/system/media/okular
    ../../../features/system/media/spotify
    ../../../features/system/media/vlc

    # Monitoring
    ../../../features/system/monitoring/lxqt-qps

    # Network
    ../../../features/system/network/chromium
    ../../../features/system/network/firefox
    ../../../features/system/network/syncthing
    ../../../features/system/network/tor-browser

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

    # Office
    ../../../features/system/office/evince
    ../../../features/system/office/obsidian
    ../../../features/system/office/lxqt-pcmanfm-qt
    ../../../features/system/office/lxqt-archiver

    # Programming
    ../../../features/system/programming/android-tools
    ../../../features/system/programming/docker-compose
    ../../../features/system/programming/gitkraken
    # TODO: Fix. There was a security issue: CVE-2024-27297
    # ../../../features/system/programming/nixd
    ../../../features/system/programming/sqlite
    ../../../features/system/programming/nodejs
    ../../../features/system/programming/ollama

    # Security
    ../../../features/system/security/bitwarden
    ../../../features/system/security/veracrypt
    ../../../features/system/security/yubikey-manager

    # # Window Manager
    # ../../../features/system/window-manager/xfce
  ];
}
