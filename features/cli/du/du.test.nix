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
    dust = "mock-dust-package";
  };

  duModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length duModule.environment.systemPackages;
    expected = 1;
  };

  # Test that the package is created with correct attributes
  testPackageAttributes = {
    expr = (builtins.head duModule.environment.systemPackages).name;
    expected = "du";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head duModule.environment.systemPackages).version;
    expected = "1.0";
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head duModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/du\necho 'dust \"$@\"' >> $out/bin/du\nchmod +x $out/bin/du";
  # };
}
