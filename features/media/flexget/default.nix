# FlexGet automates downloading from RSS/torznab sources. Port = 5050 (web UI).
{pkgs, ...}: let
  name = "flexget";
  directoryPath = "/data/services/${name}";
  dotfilesRepo = "/data/dotfiles";
  configSource = "${dotfilesRepo}/features/media/flexget/config/config.yml";
  configFile = "${directoryPath}/config.yml";
in {
  environment = {
    systemPackages = with pkgs; [
      flexget
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "FlexGet Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          WorkingDirectory = directoryPath;
          ExecStartPre = "${pkgs.coreutils}/bin/install -m 0644 -o ${name} -g data ${configSource} ${configFile}";
          ExecStart = "${pkgs.flexget}/bin/flexget -c ${configFile} daemon start --webui";
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
