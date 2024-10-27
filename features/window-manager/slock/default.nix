# Slock is a screen lock.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    slock
  ];
}
