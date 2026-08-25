# FlexGet automates downloading from RSS/torznab sources. Port = 5050 (web UI).
#
# Uses the native services.flexget module; the YAML below is embedded into
# the Nix store at eval time and installed by the unit's ExecStartPre, so
# the repo stays the single source of truth with no host-clone dependency.
{pkgs, ...}: let
  directoryPath = "/data/services/flexget";
in {
  services.flexget = {
    enable = true;
    user = "flexget";
    homeDir = directoryPath;
    # Schedules live in the YAML (web_server + schedules sections).
    systemScheduler = false;
    config = builtins.readFile ./config/config.yml;
  };

  # FlexGet refuses to start on a stale lock ("Another process (PID ...) is
  # running"), e.g. after an unclean stop or a crash-loop. Clear it before
  # the daemon starts; the "+" prefix runs as root regardless of User=.
  systemd.services.flexget.serviceConfig.ExecStartPre = [
    "+${pkgs.coreutils}/bin/rm -f ${directoryPath}/.flexget-lock"
  ];

  systemd.tmpfiles.rules = [
    "d ${directoryPath} 0770 flexget data - -"
  ];

  users.users.flexget = {
    isSystemUser = true;
    home = "/home/flexget";
    createHome = true;
    group = "flexget";
    extraGroups = ["data"];
  };
  users.groups.flexget = {};
}
