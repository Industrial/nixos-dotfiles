{pkgs, ...}: let
  mockPkgs = {
    fzf = "mock-fzf-package";
  };

  fzfModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "fzf" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = fzfModule.environment.systemPackages;
    expected = ["mock-fzf-package"];
  };
}
