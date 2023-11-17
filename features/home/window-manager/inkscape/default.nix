# Inkscape is a vector drawing tool.
{pkgs, ...}: {
  home.packages = with pkgs; [
    inkscape
  ];
}
