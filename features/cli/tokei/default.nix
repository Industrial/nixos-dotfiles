# Tokei counts lines of code in a tree, grouped by language.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    tokei
  ];
}
