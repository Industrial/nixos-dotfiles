{
  settings,
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.microvm.nixosModules.microvm

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
    ../../../features/nix/shell

    # NixOS
    ../../../features/nixos/bluetooth
    ../../../features/nixos/boot
    ../../../features/nixos/console
    ../../../features/nixos/docker
    ../../../features/nixos/fonts
    ../../../features/nixos/i18n
    ../../../features/nixos/networking
    ../../../features/nixos/nix
    ../../../features/nixos/printing
    ../../../features/nixos/security
    ../../../features/nixos/security/yubikey
    ../../../features/nixos/sound
    ../../../features/nixos/system
    ../../../features/nixos/time
    ../../../features/nixos/users
    ../../../features/nixos/window-manager

    # Office
    # ../../../features/office/cryptpad
    ../../../features/office/evince
    ../../../features/office/lxqt-archiver
    ../../../features/office/lxqt-pcmanfm-qt
    ../../../features/office/obsidian

    # Programming
    ../../../features/programming/android-tools
    ../../../features/programming/docker-compose
    ../../../features/programming/git
    ../../../features/programming/gitkraken
    ../../../features/programming/nodejs
    ../../../features/programming/ollama
    ../../../features/programming/sqlite

    # Security
    ../../../features/security/bitwarden
    ../../../features/security/vaultwarden
    ../../../features/security/veracrypt
    ../../../features/security/yubikey-manager

    # Window Manager
    ../../../features/window-manager/xfce
    ../../../features/window-manager/alacritty

    {
      users.users.root.password = "";
      microvm = {
        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 256;
          }
        ];
        shares = [
          {
            # use "virtiofs" for MicroVMs that are started by systemd
            proto = "9p";
            tag = "ro-store";
            # a host's /nix/store will be picked up so that no
            # squashfs/erofs will be built for it.
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];

        hypervisor = "qemu";
        socket = "control.socket";
      };
    }
  ];
}
