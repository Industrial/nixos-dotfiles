# AppImage Runtime.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    appimage-run
  ];
}
