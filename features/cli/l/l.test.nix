{pkgs, ...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        buildInputs = attrs.buildInputs;
        installPhase = attrs.installPhase;
      };
    };
    eza = "mock-eza-package";
  };

  lModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length lModule.environment.systemPackages;
    expected = 1;
  };

  # Test that the package is created with correct attributes
  testPackageAttributes = {
    expr = (builtins.head lModule.environment.systemPackages).name;
    expected = "l";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head lModule.environment.systemPackages).version;
    expected = "1.0";
  };

  # Test that the package has the correct buildInputs
  testBuildInputs = {
    expr = (builtins.head lModule.environment.systemPackages).buildInputs;
    expected = ["mock-eza-package"];
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head lModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/l\necho 'eza --colour=always --icons --long --group --header --time-style long-iso --git --classify --group-directories-first --sort Extension --all \"$@\"' >> $out/bin/l\nchmod +x $out/bin/l";
  # };
}
