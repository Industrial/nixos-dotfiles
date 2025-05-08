{pkgs, ...}: let
  mockPkgs = {
    unzip = "mock-unzip-package";
  };

  unzipModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "unzip" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = unzipModule.environment.systemPackages;
    expected = ["mock-unzip-package"];
  };
}
