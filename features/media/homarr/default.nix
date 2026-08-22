# Homarr is a self-hosted dashboard for all your applications.
# Port: 7575
{config, lib, pkgs, ...}: let
  name = "homarr";
  directoryPath = "/data/services/${name}";
in {
  environment = {
    systemPackages = with pkgs; [
      nodejs-18_x  # Homarr requires Node.js
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Homarr Dashboard";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          WorkingDirectory = directoryPath;
          ExecStart = "${pkgs.nodejs-18_x}/bin/npm start";
          Environment = [
            "HOST=0.0.0.0"
            "PORT=7575"
          ];
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
  };

  tmpfiles = {
    rules = [
      "d ${directoryPath} 0770 ${name} data - -"
    ];
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
  };

  groups = {
    "${name}" = {};
  };
}
