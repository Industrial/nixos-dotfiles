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
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length module.environment.systemPackages;
    expected = 1;
  };

  # Test that the package is created with correct attributes
  testPackageAttributes = {
    expr = (builtins.head module.environment.systemPackages).name;
    expected = "c";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head module.environment.systemPackages).version;
    expected = "1.0";
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head cModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/c\necho 'code \"$@\"' >> $out/bin/c\nchmod +x $out/bin/c";
  # };
}
