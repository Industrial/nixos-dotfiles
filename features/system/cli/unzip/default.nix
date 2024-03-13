# I need unzip.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    unzip
  ];
}
