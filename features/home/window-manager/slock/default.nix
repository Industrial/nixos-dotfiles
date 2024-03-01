# Slock is a screen lock.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    slock
  ];
}
