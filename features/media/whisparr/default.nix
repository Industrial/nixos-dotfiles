# TODO: Whisparr is not available on NixOS yet.
# Whisparr is a software that helps you find, download and organize your PORN ITS PORN
{pkgs, ...}: let
  # port = 6969;
in {
  environment = {
    systemPackages = with pkgs; [
      whisparr
    ];
  };

  systemd = {
    services = {
      whisparr = {
        description = "Whisparr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "whisparr";
          Group = "data";
          ExecStart = "${pkgs.whisparr}/bin/Whisparr --nobrowser --data=/data/whisparr";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d /data/whisparr 0770 whisparr data - -"
        "d /data/whisparr/data 0770 whisparr data - -"
      ];
    };
  };

  users = {
    users = {
      whisparr = {
        isSystemUser = true;
        home = "/home/whisparr";
        createHome = true;
        group = "whisparr";
        extraGroups = ["data"];
      };
    };

    groups = {
      whisparr = {};
    };
  };
}
