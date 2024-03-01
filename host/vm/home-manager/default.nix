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
    # ../../../features/home/window-manager/dwm
    ../../../features/home/window-manager/xmonad
  ];
}
