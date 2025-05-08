{pkgs, ...}: let
  mockPkgs = {
    jq = "mock-jq-package";
  };

  jqModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "jq" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = jqModule.environment.systemPackages;
    expected = ["mock-jq-package"];
  };
}
