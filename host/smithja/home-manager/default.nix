{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/ansifilter
    ../../../features/home/cli/base16-schemes
    ../../../features/home/cli/bat
    ../../../features/home/cli/btop
    ../../../features/home/cli/direnv
    ../../../features/home/cli/dust
    ../../../features/home/cli/eza
    ../../../features/home/cli/fd
    ../../../features/home/cli/fish
    ../../../features/home/cli/fzf
    ../../../features/home/cli/htop
    ../../../features/home/cli/neovim
    ../../../features/home/cli/ranger
    ../../../features/home/cli/ripgrep
    ../../../features/home/cli/unzip
    ../../../features/home/cli/zellij

    # Communication
    ../../../features/home/communication/discord

    # Home
    ../../../features/home/home

    # Media
    ../../../features/home/media/spotify

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/gitkraken

    # Window Manager
    ../../../features/home/window-manager/gimp
    ../../../features/home/window-manager/inkscape
    ../../../features/home/window-manager/obsidian
    ../../../features/home/window-manager/vscode
  ];
}
