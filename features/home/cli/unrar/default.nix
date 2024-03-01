# I need unrar.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    unrar
  ];
}
