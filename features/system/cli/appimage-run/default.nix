# AppImage Runtime.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    appimage-run
  ];
}
