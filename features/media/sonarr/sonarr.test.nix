{pkgs, ...}: let
  mockPkgs = {
    sonarr = "mock-sonarr-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
  name = "sonarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "sonarr" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-sonarr-package"];
  };

  # Test systemd service description and targets
  testServiceMetadata = {
    expr = {
      description = module.systemd.services.sonarr.description;
      wantedBy = module.systemd.services.sonarr.wantedBy;
      after = module.systemd.services.sonarr.after;
    };
    expected = {
      description = "Sonarr Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };

  # Test systemd service configuration
  testServiceConfig = {
    expr = module.systemd.services.sonarr.serviceConfig;
    expected = {
      Type = "simple";
      User = name;
      Group = "data";
      ExecStart = "mock-sonarr-package/bin/NzbDrone --nobrowser --data=${directoryPath}";
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
    expr = module.users.users.sonarr;
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
    expr = module.users.groups.sonarr;
    expected = {};
  };
}
