{...}: {
  services.xserver.enable = true;
  services.xserver.dpi = 96;
  services.xserver.layout = "us";
  services.xserver.xkbVariant = "";
  services.xserver.displayManager.defaultSession = "xfce";
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];
}
