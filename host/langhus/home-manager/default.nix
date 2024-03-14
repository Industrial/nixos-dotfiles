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

    # Games
    ../../../features/home/games/lutris

    # Home
    ../../../features/home/home

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/vscode

    # Window Manager
    ../../../features/home/window-manager/alacritty
    ../../../features/home/window-manager/dwm
    ../../../features/home/window-manager/slock
    ../../../features/home/window-manager/stylix
    ../../../features/home/window-manager/xmonad
    inputs.stylix.homeManagerModules.stylix
  ];
}
