{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      flatpak
    ];
  };
}
