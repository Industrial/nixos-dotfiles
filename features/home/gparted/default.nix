# gparted is a disk partition manager
{pkgs, ...}: {
  home.packages = with pkgs; [
    gparted
  ];
}
