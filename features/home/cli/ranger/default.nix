# Ranger is a file browser for the command line.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ranger
  ];
}
