{pkgs, ...}: let
  mockPkgs = {
    radarr = "mock-radarr-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
  name = "radarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "radarr" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-radarr-package"];
  };

  # Test systemd service description and targets
  testServiceMetadata = {
    expr = {
      description = module.systemd.services.radarr.description;
      wantedBy = module.systemd.services.radarr.wantedBy;
      after = module.systemd.services.radarr.after;
    };
    expected = {
      description = "Radarr Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };

  # Test systemd service configuration
  testServiceConfig = {
    expr = module.systemd.services.radarr.serviceConfig;
    expected = {
      Type = "simple";
      User = name;
      Group = "data";
      ExecStart = "mock-radarr-package/bin/Radarr --nobrowser --data=${directoryPath}";
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
    expr = module.users.users.radarr;
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
    expr = module.users.groups.radarr;
    expected = {};
  };
}
