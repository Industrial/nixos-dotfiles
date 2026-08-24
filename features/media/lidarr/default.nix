# Lidarr is a music collection manager for Usenet and BitTorrent users, port = 8686.
{pkgs, ...}: let
  name = "lidarr";
  directoryPath = "/data/services/${name}";
  # Cursor-pattern declarative config: the file lives in the dotfiles repo
  # (cloned at /data/dotfiles on mimir) and is symlinked into the service's
  # data dir. Lidarr rewrites config.xml on UI changes, so the repo file is
  # made group-writable for the service's 'data' group — owner-side git
  # access is preserved.
  dotfilesRepo = "/data/dotfiles";
  configSource = "${dotfilesRepo}/features/media/lidarr/config/config.xml";
in {
  environment = {
    systemPackages = with pkgs; [
      lidarr
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Lidarr Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          ExecStart = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data=${directoryPath}";
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

  # Link the declarative config into the service data dir (idempotent).
  # A pre-existing real file is backed up once before the first link takes
  # over; a missing repo checkout degrades gracefully to the live file.
  system.activationScripts.lidarrConfig = {
    text = ''
      source="${configSource}"
      target="${directoryPath}/config.xml"
      if [ ! -f "$source" ]; then
        echo "lidarr: $source missing (is ${dotfilesRepo} cloned?); keeping existing config" >&2
      else
        mkdir -p "$(dirname "$target")"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          if ! ${pkgs.diffutils}/bin/cmp -s "$target" "$source"; then
            cp -a "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
          fi
        fi
        ln -sfn "$source" "$target"
        chgrp data "$source" 2>/dev/null || true
        chmod 0664 "$source"
      fi
    '';
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
