{pkgs, ...}: let
  mockPkgs = {
    unrar = "mock-unrar-package";
  };

  unrarModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "unrar" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = unrarModule.environment.systemPackages;
    expected = ["mock-unrar-package"];
  };
}
