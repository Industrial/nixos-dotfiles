{...}: let
  mockPkgs = {
    rustPlatform = {
      buildRustPackage = attrs: {
        pname = attrs.pname;
        version = attrs.version;
        src = attrs.src;
        cargoLock = attrs.cargoLock;
        meta = attrs.meta;
      };
    };
    lib = {
      licenses = {
        mit = "MIT";
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
    expr = (builtins.head module.environment.systemPackages).pname;
    expected = "cl";
  };

  # Test that the package has the correct version
  testPackageVersion = {
    expr = (builtins.head module.environment.systemPackages).version;
    expected = "0.1.0";
  };

  # Test that the package has the correct source path
  testSourcePath = {
    expr = (builtins.head module.environment.systemPackages).src;
    expected = ../../../rust/tools/cl;
  };

  # Test that the package has the correct cargo lock file
  testCargoLock = {
    expr = (builtins.head module.environment.systemPackages).cargoLock.lockFile;
    expected = ../../../rust/tools/cl/Cargo.lock;
  };

  # Test that the package has the correct meta information
  testMetaInfo = {
    expr = {
      description = (builtins.head module.environment.systemPackages).meta.description;
      license = (builtins.head module.environment.systemPackages).meta.license;
    };
    expected = {
      description = "A simple terminal clear command written in Rust";
      license = "MIT";
    };
  };
}
