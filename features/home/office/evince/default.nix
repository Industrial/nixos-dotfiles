# evince is a document reader (gnome).
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    evince
  ];
}
