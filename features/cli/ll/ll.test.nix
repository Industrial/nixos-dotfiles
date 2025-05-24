{...}: let
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
    expected = "ll";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head module.environment.systemPackages).version;
    expected = "1.0";
  };

  # Test that the package has the correct buildInputs
  testBuildInputs = {
    expr = (builtins.head module.environment.systemPackages).buildInputs;
    expected = ["mock-eza-package"];
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head llModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/ll\necho 'eza --colour=always --icons --long --group --header --time-style long-iso --git --classify --group-directories-first --sort Extension \"$@\"' >> $out/bin/ll\nchmod +x $out/bin/ll";
  # };
}
