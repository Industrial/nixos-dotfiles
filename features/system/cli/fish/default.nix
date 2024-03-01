# Fish Plugins, not installable with home manager.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    fishPlugins.bass
    fishPlugins.fzf
  ];
}
