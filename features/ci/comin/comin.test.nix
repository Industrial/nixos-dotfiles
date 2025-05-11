{...}: let
  mockSettings = {
    hostname = "test-host";
  };

  cominModule = import ./default.nix {settings = mockSettings;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = cominModule.services.comin;
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
    expr = cominModule.services.comin.flakeSubdirectory;
    expected = "hosts/test-host";
  };

  # Test that the hostname is correctly set
  testHostname = {
    expr = cominModule.services.comin.hostname;
    expected = "test-host";
  };

  # Test that the remote configuration is correct
  testRemoteConfig = {
    expr = cominModule.services.comin.remotes;
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
