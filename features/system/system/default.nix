# This is the system feature. It should at least be included.
{pkgs, ...}: {
  imports = [
    ../../../hardware-configuration.nix
  ];
}
