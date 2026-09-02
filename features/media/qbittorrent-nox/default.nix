# Qbittorrent-nox is a headless BitTorrent client. Port = 8080 (Web UI), 8999 (BT listener)
{pkgs, ...}: let
  name = "qbittorrent-nox";
  directoryPath = "/data/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      qbittorrent-nox
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Qbittorrent-nox Headless Torrent Client";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
      ];
    };
  };

  users = {
    users = {
      "${name}" = {
        isSystemUser = true;
        home = "/home/${name}";
        createHome = true;
        group = "${name}";
        extraGroups = ["data"];
      };
    };
    groups = {
      "${name}" = {};
    };
  };
}
