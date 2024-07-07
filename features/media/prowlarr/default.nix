# Prowlarr is a software that allows you to manage multiple indexers for your torrent client.
{pkgs, ...}: let
  port = 9696;
in {
  environment = {
    systemPackages = with pkgs; [
      prowlarr
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
      prowlarr = {
        description = "Prowlarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "prowlarr";
          Group = "data";
          ExecStart = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data /data/prowlarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };

  users = {
    users = {
      prowlarr = {
        isSystemUser = true;
        group = "data";
      };
    };
  };
}
