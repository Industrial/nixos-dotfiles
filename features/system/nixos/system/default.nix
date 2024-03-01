# This is the system feature. It should at least be included.
{
  settings,
  pkgs,
  ...
}: {
  programs.dconf.enable = true;
}
