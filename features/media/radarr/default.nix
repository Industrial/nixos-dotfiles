# Radarr is a movie collection manager for Usenet and BitTorrent users. Port = 7878.
{pkgs, ...}: let
  name = "radarr";
  directoryPath = "/data/services/${name}";
  # Cursor-pattern declarative config: the file lives in the dotfiles repo
  # (cloned at /data/dotfiles on mimir) and is symlinked into the service's
  # data dir. Radarr rewrites config.xml on UI changes, so the repo file is
  # made group-writable for the service's 'data' group — owner-side git
  # access is preserved.
  dotfilesRepo = "/data/dotfiles";
  configSource = "${dotfilesRepo}/features/media/radarr/config/config.xml";
in {
  environment = {
    systemPackages = with pkgs; [
      radarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Radarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.radarr}/bin/Radarr --nobrowser --data=${directoryPath}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };

    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
        "d ${directoryPath}/data 0770 ${name} data - -"
        # The declarative config, linked from the checkout (GH-219, was the activation
        # script radarrConfig). `L`, not `L+`: a real config.xml already there is left
        # alone rather than deleted, so a live config is never lost; remove it by hand
        # to let the link take over. Unlike the script, a missing checkout is not skipped:
        # the link dangles until /data/dotfiles is cloned, and the service cannot save.
        "L ${directoryPath}/config.xml - - - - ${configSource}"
        # The service rewrites config.xml on UI changes, through the link: the repo file
        # is group-writable for the data group, its owner (git access) unchanged.
        "z ${configSource} 0664 - data - -"
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
