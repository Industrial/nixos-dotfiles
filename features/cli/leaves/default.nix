# Leaves is a text-mode disk usage treemap visualization utility.
{pkgs, ...}: {
  environment.systemPackages = [(pkgs.callPackage ./package.nix {})];
}
