# SqLite.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    sqlite
  ];
}
