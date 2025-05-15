{pkgs, ...}: let
  mockPkgs = {
    nodePackages_latest = {
      claude-task-master = "mock-claude-task-master-package";
    };
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "bat" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-claude-task-master-package"
    ];
  };
}
