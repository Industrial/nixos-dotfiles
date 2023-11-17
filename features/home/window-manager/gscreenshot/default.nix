# Gscreenshot is a screenshotting tool.
{pkgs, ...}: {
  home.packages = with pkgs; [
    gscreenshot
  ];
}
