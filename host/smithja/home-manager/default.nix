{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/fish
    ../../../features/home/cli/neovim
    ../../../features/home/cli/zellij

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
