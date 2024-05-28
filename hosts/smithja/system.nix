{
  settings,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    #inputs.microvm.nixosModules.host

    # CLI
    ../../features/cli/ansifilter
    # TODO: Not available on darwin
    # ../../features/cli/appimage-run
    ../../features/cli/bat
    ../../features/cli/btop
    ../../features/cli/direnv
    ../../features/cli/e2fsprogs
    ../../features/cli/eza
    ../../features/cli/fd
    ../../features/cli/fish
    ../../features/cli/fzf
    ../../features/cli/gh
    ../../features/cli/killall
    ../../features/cli/jira-cli
    # ../../features/cli/lazygit
    ../../features/cli/neofetch
    ../../features/cli/p7zip
    ../../features/cli/ranger
    ../../features/cli/ripgrep
    ../../features/cli/starship
    ../../features/cli/unrar
    ../../features/cli/unzip
    ../../features/cli/zellij

    # Communication
    ../../features/communication/discord

    # # Crypto
    # ../../features/crypto/monero

    # # Filesystems
    # ../../features/filesystems/gparted

    # # Games
    # ../../features/games/lutris
    # ../../features/games/path-of-building
    # ../../features/games/steam

    # # Hardware
    # ../../features/hardware/zsa-keyboard

    # Media
    # ../../features/media/invidious
    # ../../features/media/lxqt-pavucontrol-qt
    # ../../features/media/lxqt-screengrab
    # ../../features/media/okular
    ../../features/media/spotify
    # ../../features/media/vlc

    # # Monitoring
    # ../../features/monitoring/grafana
    # ../../features/monitoring/homepage-dashboard
    # ../../features/monitoring/lxqt-qps
    # ../../features/monitoring/prometheus

    # Nix
    ../../features/nix
    ../../features/nix/nixpkgs
    ../../features/nix/nix-unit
    ../../features/nix/shell

    # # NixOS
    # # ../../features/nixos/docker
    # # ../../features/nixos/networking
    # # ../../features/nixos/security/apparmor
    # # ../../features/nixos/security/clamav
    # ../../features/nixos/bluetooth
    # ../../features/nixos/boot
    # ../../features/nixos/console
    # ../../features/nixos/fonts
    # ../../features/nixos/i18n
    # ../../features/nixos/printing
    # ../../features/nixos/security
    # ../../features/nixos/security/yubikey
    # ../../features/nixos/sound
    # ../../features/nixos/system
    # ../../features/nixos/time
    # ../../features/nixos/users
    # ../../features/nixos/window-manager

    # Office
    # ../../features/office/cryptpad
    ../../features/office/evince
    # ../../features/office/lxqt-archiver
    # ../../features/office/lxqt-pcmanfm-qt
    ../../features/office/obsidian

    # Programming
    # ../../features/programming/android-tools
    ../../features/programming/bun
    ../../features/programming/deno
    # ../../features/programming/docker-compose
    ../../features/programming/edgedb
    ../../features/programming/git
    ../../features/programming/gitkraken
    ../../features/programming/glogg
    # TODO: Not available on darwin
    # ../../features/programming/insomnia
    # TODO: Not available on darwin
    # ../../features/programming/local-ai
    ../../features/programming/meld
    ../../features/programming/nixd
    ../../features/programming/nodejs
    # TODO: Not available on darwin
    # ../../features/programming/ollama
    ../../features/programming/sqlite
    ../../features/programming/vscode

    # Security
    # ../../features/security/bitwarden
    # ../../features/security/vaultwarden
    # ../../features/security/veracrypt
    # ../../features/security/yubikey-manager

    # Window Manager
    # ../../features/window-manager/dwm
    # ../../features/window-manager/xmonad
    # ../../features/window-manager/alacritty
    # ../../features/window-manager/hyper
    # ../../features/window-manager/stylix
    # ../../features/window-manager/xfce
    # inputs.stylix.nixosModules.stylix
  ];

  services.nix-daemon.enable = true;
}
