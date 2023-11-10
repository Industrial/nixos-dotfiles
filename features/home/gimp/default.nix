# Gimp is an image editing tool.
{pkgs, ...}: {
  home.packages = with pkgs; [
    gimp
  ];
}
