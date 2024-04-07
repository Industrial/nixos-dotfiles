{
  settings,
  pkgs,
  ...
}: {
  services.xserver.enable = true;
  services.xserver.dpi = 96;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
}
