{pkgs, ...}: let
  module = import ./default.nix {inherit pkgs;};
  username = "jellyfin";
  directoryPath = "/mnt/well/services/jellyfin";
in {
  # Test that the service is enabled
  testServiceEnabled = {
    expr = module.services.jellyfin.enable;
    expected = true;
  };

  # Test service configuration
  testServiceConfig = {
    expr = {
      configDir = module.services.jellyfin.configDir;
      logDir = module.services.jellyfin.logDir;
      cacheDir = module.services.jellyfin.cacheDir;
      dataDir = module.services.jellyfin.dataDir;
    };
    expected = {
      configDir = "${directoryPath}/config";
      logDir = "${directoryPath}/log";
      cacheDir = "${directoryPath}/cache";
      dataDir = "${directoryPath}/data";
    };
  };

  # Test tmpfiles rules
  testTmpfilesRules = {
    expr = module.systemd.tmpfiles.rules;
    expected = [
      "d ${directoryPath} 0770 ${username} data - -"
      "d ${directoryPath}/data 0770 ${username} data - -"
    ];
  };

  # Test user configuration
  testUserConfig = {
    expr = module.users.users.${username};
    expected = {
      isSystemUser = true;
      home = "/home/${username}";
      createHome = true;
      group = username;
      extraGroups = ["data"];
    };
  };

  # Test group configuration
  testGroupConfig = {
    expr = module.users.groups.${username};
    expected = {};
  };
}
