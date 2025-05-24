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
    fractal = "mock-fractal-package";
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
    expr = builtins.hasAttr "fractal" mockPkgs;
    expected = true;
  };

  # Test that Fractal is in system packages
  testFractalInSystemPackages = {
    expr = builtins.elem mockPkgs.fractal module.environment.systemPackages;
    expected = true;
  };
}
