{
  pkgs ? import <nixpkgs> {}, # Ensure pkgs is available
  lib ? pkgs.lib, # Ensure lib is available
  inputs ? {
    # Provide a default for inputs if not passed by test runner
    cl-src = ../../../rust/tools/cl;
  },
  ... # Allow other arguments from the test runner
}: let
  # Evaluate the module, passing the necessary pkgs, lib, and inputs
  evaluatedModule = import ./default.nix {inherit pkgs lib inputs;};

  # Helper to get the system packages list from the evaluated module
  systemPackages = evaluatedModule.environment.systemPackages;

  # Helper to get the cl package from the system packages list
  clPackageFromModule =
    if builtins.length systemPackages > 0
    then
      if (builtins.head systemPackages).pname == "cl"
      then # Basic check
        builtins.head systemPackages
      else null # Should not happen if module works as expected
    else null;
in {
  testModuleAddsOneClPackage = {
    expr = builtins.length systemPackages == 1 && clPackageFromModule != null;
    expected = true;
    message = "The cl module should add exactly one package named 'cl' to environment.systemPackages.";
  };

  # The following tests depend on clPackageFromModule being correctly found.
  # They will fail if clPackageFromModule is null due to the expr definitions.

  testPackagePnameIsCl = {
    expr =
      if clPackageFromModule != null
      then clPackageFromModule.pname
      else "error: clPackageFromModule was null";
    expected = "cl";
    message = "The pname of the added package should be 'cl'.";
  };

  testPackageVersionIsCorrect = {
    expr =
      if clPackageFromModule != null
      then clPackageFromModule.version
      else "error: clPackageFromModule was null";
    expected = "0.1.0"; # This should match the version in rust/tools/cl/default.nix
    message = "The version of the cl package should be '0.1.0'.";
  };

  testPackageSrcIsNotNull = {
    expr =
      if clPackageFromModule != null
      then clPackageFromModule.src != null
      else false;
    expected = true;
    message = "The src attribute of the cl package should not be null.";
  };

  testMetaDescriptionIsCorrect = {
    expr =
      if clPackageFromModule != null
      then clPackageFromModule.meta.description
      else "error: clPackageFromModule was null";
    expected = "A simple terminal clear command written in Rust"; # From rust/tools/cl/default.nix
    message = "The description of the cl package is not correct.";
  };

  testMetaLicenseIsMIT = {
    expr =
      if clPackageFromModule != null
      then clPackageFromModule.meta.license.spdxId
      else "error: clPackageFromModule was null";
    expected = "MIT"; # From rust/tools/cl/default.nix
    message = "The license of the cl package should be MIT (SPDX ID).";
  };
}
