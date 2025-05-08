{pkgs, ...}: let
  mockPkgs = {
    btop = "mock-btop-package";
  };

  btopModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "btop" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = btopModule.environment.systemPackages;
    expected = ["mock-btop-package"];
  };
}
