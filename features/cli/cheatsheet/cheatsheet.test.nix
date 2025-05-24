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
    expected = "cheatsheet";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head module.environment.systemPackages).version;
    expected = "1.0";
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head cheatsheetModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/cheatsheet\necho 'cat ~/.config/cheatsheet/cheatsheet.txt' >> $out/bin/cheatsheet\nchmod +x $out/bin/cheatsheet";
  # };
}
