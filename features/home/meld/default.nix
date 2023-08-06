# Meld is a diff viewer.
{pkgs, ...}: {
  home.packages = with pkgs; [
    meld
  ];
}
