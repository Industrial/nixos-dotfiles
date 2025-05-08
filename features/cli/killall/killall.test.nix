{pkgs, ...}: let
  mockPkgs = {
    killall = "mock-killall-package";
  };

  killallModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "killall" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = killallModule.environment.systemPackages;
    expected = ["mock-killall-package"];
  };
}
