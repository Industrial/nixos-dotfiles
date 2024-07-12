# A Fast, Easy and Free Bittorrent Client For macOS, Windows and Linux.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    transmission_4
    transmission_4-qt
  ];

  services = {
    transmission = {
      enable = true;
      package = pkgs.transmission_4;
      user = "transmission";
      group = pkgs.lib.mkForce "data";
      home = "/home/transmission";
      openFirewall = false;
      openPeerPorts = false;
      openRPCPort = false;
      downloadDirPermissions = "770";
      settings = {
        download-dir = "/data/transmission/downloads";
        incomplete-dir = "/data/transmission/incomplete";
        incomplete-dir-enabled = true;
        watch-dir = "/data/transmission/watch";
        watch-dir-enabled = true;
      };
    };
  };

  users = {
    users = {
      transmission = {
        isSystemUser = true;
        home = "/home/transmission";
        createHome = true;
        group = pkgs.lib.mkForce "transmission";
        extraGroups = ["data"];
      };
    };
    groups = {
      transmission = {};
    };
  };
}
