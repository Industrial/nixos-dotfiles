{pkgs, ...}: {
  services.xserver.enable = true;
  services.xserver.dpi = 96;
  services.xserver.layout = "us";
  services.xserver.xkbVariant = "";
  services.xserver.displayManager.defaultSession = "xfce";
  services.xserver.desktopManager.xfce.enable = true;
  programs.thunar.plugins = with pkgs; [
    xfce.thunar-archive-plugin
  ];
  services.xserver.videoDrivers = ["amdgpu"];
}