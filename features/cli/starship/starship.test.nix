{pkgs, ...}: let
  mockPkgs = {
    starship = "mock-starship-package";
  };

  starshipModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "starship" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = starshipModule.environment.systemPackages;
    expected = ["mock-starship-package"];
  };
}
