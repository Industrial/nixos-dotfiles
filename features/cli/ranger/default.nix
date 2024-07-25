# Ranger is a file browser for the command line.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ranger
  ];
}
