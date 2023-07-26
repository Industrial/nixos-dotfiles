{pkgs, ...}: {
  services.tor.client.enable = true;
  services.tor.enable = true;
  services.tor.openFirewall = true;

  environment.systemPackages = with pkgs; [
    tor-browser-bundle-bin
  ];
}
