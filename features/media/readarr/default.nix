# Readarr is a movie collection manager for Usenet and BitTorrent users
{pkgs, ...}: let
  port = 7878;
in {
  environment = {
    systemPackages = with pkgs; [
      readarr
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
      readarr = {
        description = "Readarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "readarr";
          Group = "data";
          ExecStart = "${pkgs.readarr}/bin/Readarr --nobrowser --data /data/readarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };

  users = {
    users = {
      readarr = {
        isSystemUser = true;
        group = "data";
      };
    };
  };
}
