# Radarr is a movie collection manager for Usenet and BitTorrent users
{pkgs, ...}: let
  port = 7878;
in {
  environment = {
    systemPackages = with pkgs; [
      radarr
    ];
  };

  # TODO: Do we want this to be available on the network?
  # networking = {
  #   firewwall = {
  #     allowedTCPPorts = [
  #       8686
  #     ];
  #   };
  # };

  systemd = {
    services = {
      radarr = {
        description = "Radarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "radarr";
          Group = "data";
          ExecStart = "${pkgs.radarr}/bin/Radarr --nobrowser --data /data/radarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/radarr 0770 radarr data - -"
        "d /data/radarr/data 0770 radarr data - -"
      ];
    };
  };

  users = {
    users = {
      radarr = {
        isSystemUser = true;
        home = "/home/radarr";
        createHome = true;
        group = "radarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      radarr = {};
    };
  };
}
