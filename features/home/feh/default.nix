# Feh is an image viewer (that can set the wallpaper too).
{pkgs, ...}: {
  home.packages = with pkgs; [
    feh
  ];
}
