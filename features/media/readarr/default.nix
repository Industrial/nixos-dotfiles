# Readarr is a movie collection manager for Usenet and BitTorrent users
{pkgs, ...}: let
  # port = 7878;
in {
  environment = {
    systemPackages = with pkgs; [
      readarr
    ];
  };

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
          ExecStart = "${pkgs.readarr}/bin/Readarr --nobrowser --data=/data/readarr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/readarr 0770 readarr data - -"
        "d /data/readarr/data 0770 readarr data - -"
      ];
    };
  };

  users = {
    users = {
      readarr = {
        isSystemUser = true;
        home = "/home/readarr";
        createHome = true;
        group = "readarr";
        extraGroups = ["data"];
      };
    };

    groups = {
      readarr = {};
    };
  };
}
