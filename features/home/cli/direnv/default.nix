# Direnv sources nix environments in project directories as you cd into them.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    direnv
  ];
}
