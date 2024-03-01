# gparted is a disk partition manager
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    gparted
  ];
}
