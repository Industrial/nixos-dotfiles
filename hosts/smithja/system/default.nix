{
  settings,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # CLI
    # ../../../features/cli/appimage-run
    ../../../features/cli/ansifilter
    ../../../features/cli/bat
    ../../../features/cli/btop
    ../../../features/cli/direnv
    ../../../features/cli/e2fsprogs
    ../../../features/cli/eza
    ../../../features/cli/fd
    ../../../features/cli/fish
    ../../../features/cli/fzf
    ../../../features/cli/gh
    ../../../features/cli/lazygit
    ../../../features/cli/neofetch
    ../../../features/cli/p7zip
    ../../../features/cli/ranger
    ../../../features/cli/ripgrep
    ../../../features/cli/starship
    ../../../features/cli/unzip
    ../../../features/cli/zellij

    # Communication
    ../../../features/communication/discord

    # Media
    ../../../features/media/spotify

    # Nix
    ../../../features/nix
    ../../../features/nix/nixpkgs
    ../../../features/nix/nix-unit
    ../../../features/nix/shell

    # Office
    ../../../features/office/evince
    ../../../features/office/obsidian

    # Programming
    ../../../features/programming/git
    ../../../features/programming/gitkraken
    ../../../features/programming/neovim
    ../../../features/programming/nixd
    ../../../features/programming/nodejs
    ../../../features/programming/sqlite
    ../../../features/programming/vscode
    inputs.nixvim.nixDarwinModules.nixvim

    # Security
    # ../../../features/security/bitwarden
    # ../../../features/security/vaultwarden
    # ../../../features/security/veracrypt
    # ../../../features/security/yubikey-manager

    # Window Manager
    # ../../../features/window-manager/hyper
  ];

  services.nix-daemon.enable = true;
}
