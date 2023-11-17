# Slock is a screen lock.
{pkgs, ...}: {
  home.packages = with pkgs; [
    slock
  ];
}
