# Bittorrent client.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    transmission_4
    transmission_4-qt
  ];

  services = {
    transmission = {
      enable = true;
    };
  };
}
