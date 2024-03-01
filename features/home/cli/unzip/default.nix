# I need unzip.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    unzip
  ];
}
