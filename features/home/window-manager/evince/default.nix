# evince is a document reader (gnome).
{pkgs, ...}: {
  home.packages = with pkgs; [
    evince
  ];
}
