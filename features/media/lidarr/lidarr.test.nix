{pkgs, ...}: let
  mockPkgs = {
    lidarr = "mock-lidarr-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
  name = "lidarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "lidarr" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-lidarr-package"];
  };

  # Test systemd service description and targets
  testServiceMetadata = {
    expr = {
      description = module.systemd.services.lidarr.description;
      wantedBy = module.systemd.services.lidarr.wantedBy;
      after = module.systemd.services.lidarr.after;
    };
    expected = {
      description = "Lidarr Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };

  # Test systemd service configuration
  testServiceConfig = {
    expr = module.systemd.services.lidarr.serviceConfig;
    expected = {
      Type = "simple";
      User = name;
      Group = "data";
      ExecStart = "mock-lidarr-package/bin/Lidarr --nobrowser --data=${directoryPath}";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Test tmpfiles rules
  testTmpfilesRules = {
    expr = module.systemd.tmpfiles.rules;
    expected = [
      "d ${directoryPath} 0770 ${name} data - -"
      "d ${directoryPath}/data 0770 ${name} data - -"
    ];
  };

  # Test user configuration
  testUserConfig = {
    expr = module.users.users.lidarr;
    expected = {
      isSystemUser = true;
      home = "/home/${name}";
      createHome = true;
      group = name;
      extraGroups = ["data"];
    };
  };

  # Test group configuration
  testGroupConfig = {
    expr = module.users.groups.lidarr;
    expected = {};
  };
}
