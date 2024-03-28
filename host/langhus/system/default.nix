{
  settings,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./graphics
    ./hardware-configuration.nix
    inputs.microvm.nixosModules.host

    # CLI
    ../../../features/cli/bat
    ../../../features/cli/btop
    ../../../features/cli/direnv
    ../../../features/cli/e2fsprogs
    ../../../features/cli/eza
    ../../../features/cli/fd
    ../../../features/cli/fish
    ../../../features/cli/fzf
    ../../../features/cli/gh
    ../../../features/cli/neofetch
    ../../../features/cli/p7zip
    ../../../features/cli/ranger
    ../../../features/cli/ripgrep
    ../../../features/cli/starship
    ../../../features/cli/unrar
    ../../../features/cli/zellij

    # Communication
    ../../../features/communication/discord

    # Crypto
    ../../../features/crypto/monero

    # Filesystems
    ../../../features/filesystems/gparted

    # Finance
    ../../../features/finance/homebank

    # Games
    ../../../features/games/lutris
    ../../../features/games/path-of-building
    ../../../features/games/steam

    # Hardware
    ../../../features/hardware/zsa-keyboard

    # Media
    ../../../features/media/invidious
    ../../../features/media/lxqt-pavucontrol-qt
    ../../../features/media/lxqt-screengrab
    ../../../features/media/okular
    ../../../features/media/spotify
    ../../../features/media/vlc

    # Monitoring
    ../../../features/monitoring/grafana
    ../../../features/monitoring/lxqt-qps
    ../../../features/monitoring/prometheus

    # Network
    ../../../features/network/chromium
    ../../../features/network/firefox
    ../../../features/network/syncthing
    ../../../features/network/tor-browser
    ../../../features/network/nginx

    # Nix
    ../../../features/nix
    ../../../features/nix/nix-unit
    ../../../features/nix/shell

    # NixOS
    # ../../../features/nixos/docker
    # ../../../features/nixos/networking
    # ../../../features/nixos/security/apparmor
    # ../../../features/nixos/security/clamav
    ../../../features/nixos/bluetooth
    ../../../features/nixos/boot
    ../../../features/nixos/console
    ../../../features/nixos/fonts
    ../../../features/nixos/i18n
    ../../../features/nixos/printing
    ../../../features/nixos/security
    ../../../features/nixos/security/yubikey
    ../../../features/nixos/sound
    ../../../features/nixos/system
    ../../../features/nixos/time
    ../../../features/nixos/users
    ../../../features/nixos/window-manager

    # Office
    ../../../features/office/cryptpad
    ../../../features/office/evince
    ../../../features/office/lxqt-archiver
    ../../../features/office/lxqt-pcmanfm-qt
    ../../../features/office/obsidian

    # Programming
    # ../../../features/programming/android-tools
    # ../../../features/programming/docker-compose
    ../../../features/programming/gitkraken
    # TODO: Fix. There was a security issue: CVE-2024-27297
    # ../../../features/programming/nixd
    # ../../../features/programming/nodejs
    # ../../../features/programming/ollama
    # ../../../features/programming/sqlite
    ../../../features/programming/git
    ../../../features/programming/vscode

    # Security
    # ../../../features/security/vaultwarden
    # ../../../features/security/veracrypt
    # ../../../features/security/yubikey-manager
    ../../../features/security/bitwarden

    # Window Manager
    # ../../../features/window-manager/dwm
    # ../../../features/window-manager/xmonad
    ../../../features/window-manager/alacritty
    ../../../features/window-manager/stylix
    ../../../features/window-manager/xfce
    inputs.stylix.nixosModules.stylix

    {
      networking.hostName = settings.hostname;
      networking.useNetworkd = true;
      systemd.network.enable = true;
      systemd.network.networks."10-lan".matchConfig.Name = ["enp16s0" "vm-*"];
      systemd.network.networks."10-lan".networkConfig.Bridge = "br0";
      systemd.network.netdevs."br0".netdevConfig.Name = "br0";
      systemd.network.netdevs."br0".netdevConfig.Kind = "bridge";
      systemd.network.networks."10-lan-bridge".matchConfig.Name = "br0";
      systemd.network.networks."10-lan-bridge".networkConfig.Address = ["192.168.8.20/24" "2001:db8::a/64"];
      systemd.network.networks."10-lan-bridge".networkConfig.Gateway = "192.168.8.1";
      systemd.network.networks."10-lan-bridge".networkConfig.DNS = "192.168.8.1";
      systemd.network.networks."10-lan-bridge".networkConfig.IPv6AcceptRA = true;
      systemd.network.networks."10-lan-bridge".linkConfig.RequiredForOnline = "routable";
    }
  ];
}
