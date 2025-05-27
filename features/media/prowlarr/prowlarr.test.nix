{pkgs, ...}: let
  mockPkgs = {
    prowlarr = "mock-prowlarr-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
  name = "prowlarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "prowlarr" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-prowlarr-package"];
  };

  # Test systemd service description and targets
  testServiceMetadata = {
    expr = {
      description = module.systemd.services.prowlarr.description;
      wantedBy = module.systemd.services.prowlarr.wantedBy;
      after = module.systemd.services.prowlarr.after;
    };
    expected = {
      description = "Prowlarr Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };

  # Test systemd service configuration
  testServiceConfig = {
    expr = module.systemd.services.prowlarr.serviceConfig;
    expected = {
      Type = "simple";
      User = name;
      Group = "data";
      ExecStart = "mock-prowlarr-package/bin/Prowlarr --nobrowser --data=${directoryPath}";
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
    expr = module.users.users.prowlarr;
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
    expr = module.users.groups.prowlarr;
    expected = {};
  };
}
