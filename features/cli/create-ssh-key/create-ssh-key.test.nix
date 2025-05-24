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

  mockSettings = {
    useremail = "test@example.com";
  };

  module = import ./default.nix {
    pkgs = mockPkgs;
    settings = mockSettings;
  };
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length module.environment.systemPackages;
    expected = 1;
  };

  # Test that the package is created with correct attributes
  testPackageAttributes = {
    expr = (builtins.head module.environment.systemPackages).name;
    expected = "create-ssh-key";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head module.environment.systemPackages).version;
    expected = "1.0";
  };

  # # Test that the installPhase contains the expected commands
  # testInstallPhase = {
  #   expr = (builtins.head createSshKeyModule.environment.systemPackages).installPhase;
  #   expected = "mkdir -p $out/bin\necho '#!/usr/bin/env bash' > $out/bin/create-ssh-key\necho 'ssh-keygen -t ed25519 -C \"$@\"' >> $out/bin/create-ssh-key\nchmod +x $out/bin/create-ssh-key";
  # };
}
