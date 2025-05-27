{pkgs, ...}: let
  mockPkgs = {
    readarr = "mock-readarr-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
  name = "readarr";
  directoryPath = "/mnt/well/services/${name}";
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "readarr" pkgs;
    expected = true;
  };

  # Test system packages
  testSystemPackages = {
    expr = module.environment.systemPackages;
    expected = ["mock-readarr-package"];
  };

  # Test systemd service description and targets
  testServiceMetadata = {
    expr = {
      description = module.systemd.services.readarr.description;
      wantedBy = module.systemd.services.readarr.wantedBy;
      after = module.systemd.services.readarr.after;
    };
    expected = {
      description = "Readarr Daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
    };
  };

  # Test systemd service configuration
  testServiceConfig = {
    expr = module.systemd.services.readarr.serviceConfig;
    expected = {
      Type = "simple";
      User = name;
      Group = "data";
      ExecStart = "mock-readarr-package/bin/Readarr --nobrowser --data=${directoryPath}";
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
    expr = module.users.users.readarr;
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
    expr = module.users.groups.readarr;
    expected = {};
  };
}
