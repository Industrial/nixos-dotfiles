# Ranger is a file browser for the command line.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    ranger
  ];
}
