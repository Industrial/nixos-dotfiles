# I need unrar.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    unrar
  ];
}
