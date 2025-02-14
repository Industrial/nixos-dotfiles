# TODO: Whisparr is not available on NixOS yet.
# Whisparr is a software that helps you find, download and organize your PORN ITS PORN. Port = 6969.
{pkgs, ...}: let
  name = "whisparr";
  directoryPath = "/mnt/well/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      whisparr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Whisparr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.whisparr}/bin/Whisparr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
        "d ${directoryPath}/data 0770 ${name} data - -"
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
