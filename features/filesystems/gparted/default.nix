# gparted is a disk partition manager
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gparted
  ];
}
