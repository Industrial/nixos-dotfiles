{pkgs, ...}: let
  mockPkgs = {
    monero-cli = "mock-monero-cli-package";
    monero-gui = "mock-monero-gui-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "monero" pkgs && builtins.hasAttr "monero-gui" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors and includes both CLI and GUI packages
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-monero-cli-package"
      "mock-monero-gui-package"
    ];
  };
}
