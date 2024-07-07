# Sonarr is a software that helps you find, download and organize your TV shows.
{pkgs, ...}: let
  port = 8989;
in {
  environment = {
    systemPackages = with pkgs; [
      sonarr
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
      sonarr = {
        description = "Sonarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "sonarr";
          Group = "data";
          ExecStart = "${pkgs.sonarr}/bin/NzbDrone --nobrowser --data /data/sonarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };

  users = {
    users = {
      sonarr = {
        isSystemUser = true;
        group = "data";
      };
    };
  };
}
