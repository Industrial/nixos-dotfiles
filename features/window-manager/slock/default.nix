# Slock is a screen lock.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    slock
  ];
}
