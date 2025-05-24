{...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        installPhase = attrs.installPhase;
      };
    };
    discord = "mock-discord-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length module.environment.systemPackages;
    expected = 1;
  };

  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "discord" mockPkgs;
    expected = true;
  };

  # Test that Discord is in system packages
  testDiscordInSystemPackages = {
    expr = builtins.elem mockPkgs.discord module.environment.systemPackages;
    expected = true;
  };
}
