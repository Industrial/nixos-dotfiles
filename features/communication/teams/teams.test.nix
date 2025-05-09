{pkgs, ...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        installPhase = attrs.installPhase;
      };
    };
    teams = "mock-teams-package";
  };

  teamsModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length teamsModule.environment.systemPackages;
    expected = 1;
  };

  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "teams" mockPkgs;
    expected = true;
  };

  # Test that Teams is in system packages
  testTeamsInSystemPackages = {
    expr = builtins.elem mockPkgs.teams teamsModule.environment.systemPackages;
    expected = true;
  };
} 