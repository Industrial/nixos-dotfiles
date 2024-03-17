# gparted is a disk partition manager
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    gparted
  ];
}
