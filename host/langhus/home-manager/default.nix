{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/zellij

    # Home
    ../../../features/home/home

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/vscode

    # Window Manager
    ../../../features/home/window-manager/stylix
    inputs.stylix.homeManagerModules.stylix
  ];
}
