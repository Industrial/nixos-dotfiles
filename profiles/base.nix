# Base Profile
# Common modules shared by all hosts
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    # CI/CD Tools
    inputs.comin.nixosModules.comin
    ../features/ci/comin

    # CLI Tools
    ../features/cli/bandwhich
    ../features/cli/bat
    ../features/cli/bluetuith
    ../features/cli/broot
    ../features/cli/btop
    ../features/cli/nvtop
    ../features/cli/c
    ../features/cli/calcurse
    ../features/cli/cheatsheet
    ../features/cli/cl
    ../features/cli/create-ssh-key
    ../features/cli/oomkiller
    ../features/cli/direnv
    ../features/cli/du
    ../features/cli/dust
    ../features/cli/dysk
    ../features/cli/eza
    ../features/cli/fastfetch
    ../features/cli/fd
    ../features/cli/fish
    ../features/cli/fzf
    ../features/cli/g
    ../features/cli/gpg
    ../features/cli/gping
    ../features/cli/gix
    ../features/cli/jq
    ../features/cli/killall
    ../features/cli/l
    ../features/cli/lazygit
    ../features/cli/ll
    ../features/cli/lnav
    ../features/cli/lsusb
    ../features/cli/nix-tree
    ../features/cli/p
    ../features/cli/p7zip
    ../features/cli/procs
    ../features/cli/ranger
    ../features/cli/ripgrep
    ../features/cli/spotify-player
    ../features/cli/starship
    ../features/cli/unrar
    ../features/cli/unzip
    ../features/cli/zellij

    # Core NixOS Configuration
    ../features/nixos
    ../features/nixos/bluetooth
    ../features/nixos/boot
    ../features/nixos/docker
    ../features/nixos/fonts
    ../features/nixos/graphics
    ../features/nixos/networking
    ../features/nixos/networking/dns.nix
    ../features/nixos/networking/firewall.nix
    ../features/nixos/security/no-defaults
    ../features/nixos/security/sudo
    ../features/nixos/systemd
    ../features/nixos/sound
    ../features/nixos/users

    # Performance Optimization
    ../features/performance/environment
    ../features/performance/hardware
    ../features/performance/filesystems
    ../features/performance/memory

    # Security
    ../features/security/apparmor
    ../features/security/keepassxc
    ../features/security/pam
    ../features/security/veracrypt
    ../features/security/yubikey

    # Storage
    ../features/storage/qdirstat

    # Network Browsers
    ../features/network/chromium
    ../features/network/firefox

    # Media (common to all hosts)
    ../features/media/calibre
    ../features/media/qbittorrent
    ../features/media/spotify
    ../features/media/vlc
  ];
}
