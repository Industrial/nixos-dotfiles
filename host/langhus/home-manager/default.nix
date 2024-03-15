{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Home
    ../../../features/home/home

    # Window Manager
    ../../../features/home/window-manager/stylix
    inputs.stylix.homeManagerModules.stylix
  ];
}
