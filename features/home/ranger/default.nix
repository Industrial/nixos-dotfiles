# Ranger is a file browser for the command line.
{pkgs, ...}: {
  home.packages = with pkgs; [
    ranger
  ];
}
