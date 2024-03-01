# SqLite.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    sqlite
  ];
}
