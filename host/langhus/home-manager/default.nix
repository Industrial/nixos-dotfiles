{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
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
