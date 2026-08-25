# Transmission is a BitTorrent client. Port = 9091 (RPC), 51413 (peer).
{pkgs, ...}: let
  name = "transmission";
  directoryPath = "/data/services/${name}";
  configDir = "${directoryPath}/.config/transmission-daemon";
  dotfilesRepo = "/data/dotfiles";
  settingsSource = "${dotfilesRepo}/features/media/transmission/config/settings.json";
in {
  environment = {
    systemPackages = with pkgs; [
      transmission_4
    ];
  };

  systemd = {
    services = {
      "${name}" = {
        description = "Transmission BitTorrent Daemon";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "simple";
          User = "${name}";
          Group = "data";
          # -g is the SETTINGS dir (transmission-daemon resolves
          # settings.json directly inside it) — pointing it at the data
          # root made the daemon ignore our declarative settings.json and
          # self-generate defaults with rpc-host-whitelist enabled (403s).
          ExecStart = "${pkgs.transmission_4}/bin/transmission-daemon -f -g ${configDir}";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${configDir}";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${name} data - -"
        "d ${directoryPath}/downloads 0770 ${name} data - -"
      ];
    };
  };

  # Link the declarative settings.json into the daemon config dir
  # (idempotent). A pre-existing real file is backed up once before the
  # first link takes over; a missing repo checkout degrades gracefully to
  # the live file. Group-writable source so UI edits flow back through NFS.
  system.activationScripts.transmissionSettings = {
    text = ''
      source="${settingsSource}"
      target="${configDir}/settings.json"
      if [ ! -f "$source" ]; then
        echo "transmission: $source missing (is ${dotfilesRepo} cloned?); keeping existing settings" >&2
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
