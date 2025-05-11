{pkgs, ...}: let
  mockPkgs = {
    gping = "mock-gping-package";
  };

  gpingModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "bat" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = gpingModule.environment.systemPackages;
    expected = [
      "mock-gping-package"
    ];
  };
}
