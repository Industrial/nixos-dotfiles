{pkgs, ...}: let
  mockPkgs = {
    gnupg = "mock-gnupg-package";
    pinentry-all = "mock-pinentry-package";
  };

  gpgModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "gnupg" pkgs && builtins.hasAttr "pinentry-all" pkgs;
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = gpgModule.environment.systemPackages;
    expected = ["mock-gnupg-package" "mock-pinentry-package"];
  };

  # Test that gnupg agent is enabled
  testGnupgAgentEnabled = {
    expr = gpgModule.programs.gnupg.agent.enable;
    expected = true;
  };

  # Test that browser socket is enabled
  testBrowserSocketEnabled = {
    expr = gpgModule.programs.gnupg.agent.enableBrowserSocket;
    expected = true;
  };
}
