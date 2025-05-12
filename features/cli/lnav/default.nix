# Lnav is a terminal log file viewer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lnav
  ];
}
