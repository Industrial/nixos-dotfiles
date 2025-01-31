# Jellyfin is a Free Software Media System that puts you in control of managing and streaming your media.
# Ports:
# 8096/tcp is used by default for HTTP traffic. You can change this in the dashboard.
# 8920/tcp is used by default for HTTPS traffic. You can change this in the dashboard.
# 1900/udp is used for service auto-discovery. This is not configurable.
# 7359/udp is also used for auto-discovery. This is not configurable.
{pkgs, ...}: let
  username = "jellyfin";
  directoryPath = "/mnt/well/services/jellyfin";
in {
  services = {
    jellyfin = {
      enable = true;
      configDir = "${directoryPath}/config";
      logDir = "${directoryPath}/log";
      cacheDir = "${directoryPath}/cache";
      dataDir = "${directoryPath}/data";
    };
  };

  systemd = {
    tmpfiles = {
      rules = [
        "d ${directoryPath} 0770 ${username} data - -"
        "d ${directoryPath}/data 0770 ${username} data - -"
      ];
    };
  };

  users = {
    users = {
      "${username}" = {
        isSystemUser = true;
        home = "/home/${username}";
        createHome = true;
        group = "${username}";
        extraGroups = ["data"];
      };
    };

    groups = {
      "${username}" = {};
    };
  };
}
