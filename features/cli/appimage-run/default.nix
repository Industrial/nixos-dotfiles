# AppImage Runtime.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    appimage-run
  ];
}
