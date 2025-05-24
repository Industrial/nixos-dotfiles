{...}: let
  mockSettings = {
    hostname = "test-host";
  };

  module = import ./default.nix {settings = mockSettings;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.services.comin;
    expected = {
      enable = true;
      flakeSubdirectory = "hosts/test-host";
      hostname = "test-host";
      remotes = [
        {
          name = "origin";
          url = "https://github.com/Industrial/nixos-dotfiles.git";
          branches = {
            main = {
              name = "main";
            };
          };
        }
      ];
    };
  };

  # Test that the flakeSubdirectory is correctly constructed
  testFlakeSubdirectory = {
    expr = module.services.comin.flakeSubdirectory;
    expected = "hosts/test-host";
  };

  # Test that the hostname is correctly set
  testHostname = {
    expr = module.services.comin.hostname;
    expected = "test-host";
  };

  # Test that the remote configuration is correct
  testRemoteConfig = {
    expr = module.services.comin.remotes;
    expected = [
      {
        name = "origin";
        url = "https://github.com/Industrial/nixos-dotfiles.git";
        branches = {
          main = {
            name = "main";
          };
        };
      }
    ];
  };
}
