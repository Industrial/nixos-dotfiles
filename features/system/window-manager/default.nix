{pkgs, ...}: {
  services.xserver.enable = true;
  services.xserver.dpi = 96;
  services.xserver.layout = "us";
  services.xserver.xkbVariant = "";
  services.xserver.videoDrivers = ["amdgpu"];
  services.xserver.displayManager.startx.enable = true;
  services.xserver.displayManager.gdm.enable = false;
  services.xserver.displayManager.lightdm.enable = false;
  services.xserver.desktopManager.xfce.enable = false;
  environment.systemPackages = with pkgs; [
    xorg.xinit
  ];
}
