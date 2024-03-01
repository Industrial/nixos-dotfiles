{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/bat
    ../../../features/home/cli/btop
    ../../../features/home/cli/direnv
    ../../../features/home/cli/e2fsprogs
    ../../../features/home/cli/eza
    ../../../features/home/cli/fd
    ../../../features/home/cli/fish
    ../../../features/home/cli/fzf
    ../../../features/home/cli/gh
    ../../../features/home/cli/neofetch
    ../../../features/home/cli/neovim
    ../../../features/home/cli/p7zip
    ../../../features/home/cli/ranger
    ../../../features/home/cli/ripgrep
    ../../../features/home/cli/unrar
    ../../../features/home/cli/unzip
    ../../../features/home/cli/zellij

    # Communication
    ../../../features/home/communication/discord

    # Home
    ../../../features/home/home

    # Media
    ../../../features/home/media/spotify

    # Office
    ../../../features/home/office/evince
    ../../../features/home/office/obsidian

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/gitkraken
    ../../../features/home/programming/nixd
    ../../../features/home/programming/nodejs
    ../../../features/home/programming/sqlite
    ../../../features/home/programming/vscode
  ];
}
