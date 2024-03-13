# Direnv sources nix environments in project directories as you cd into them.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    direnv
  ];
}
