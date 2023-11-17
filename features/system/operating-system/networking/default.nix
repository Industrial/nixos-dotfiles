{pkgs, c9config, ...}: {
  networking.networkmanager.enable = true;
  networking.hostName = c9config.hostname;
}
