{pkgs, ...}: let
  mockPkgs = {
    dysk = "mock-dysk-package";
  };

  dyskModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "dysk" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = dyskModule.environment.systemPackages;
    expected = ["mock-dysk-package"];
  };
}
