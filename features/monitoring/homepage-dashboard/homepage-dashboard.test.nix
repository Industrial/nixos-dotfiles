{
  settings ? {
    hostname = "test.local";
  },
  ...
}: let
  module = import ./default.nix {inherit settings;};
in {
  # Test that the service is enabled
  testServiceEnabled = {
    expr = module.services.homepage-dashboard.enable;
    expected = true;
  };

  # Test listen port
  testListenPort = {
    expr = module.services.homepage-dashboard.listenPort;
    expected = 8080;
  };

  # Test basic settings
  testBasicSettings = {
    expr = module.services.homepage-dashboard.settings;
    expected = {
      title = "Dashboard";
      theme = "dark";
      color = "slate";
    };
  };

  # Test bookmarks structure
  testBookmarksStructure = {
    expr = builtins.length module.services.homepage-dashboard.bookmarks;
    expected = 2;
  };

  # Test services structure
  testServicesStructure = {
    expr = builtins.length module.services.homepage-dashboard.services;
    expected = 5;
  };

  # Test widgets configuration
  testWidgetsConfig = {
    expr = module.services.homepage-dashboard.widgets;
    expected = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
  };
}
