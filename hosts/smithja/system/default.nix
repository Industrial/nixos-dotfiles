{
  settings,
  pkgs,
  ...
}: {
  imports = [
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
    ../../../features/cli/unzip
    ../../../features/cli/zellij

    # Communication
    ../../../features/communication/discord

    # Media
    ../../../features/media/spotify

    # Office
    ../../../features/office/evince
    ../../../features/office/obsidian

    # Programming
    # ../../../features/programming/nixd
    ../../../features/programming/git
    ../../../features/programming/gitkraken
    ../../../features/programming/nodejs
    ../../../features/programming/sqlite
    ../../../features/programming/vscode

    # Nix
    ../../../features/nix
    ../../../features/nix/nix-unit
    ../../../features/nix/shell
  ];

  services.nix-daemon.enable = true;
}
