{
  pkgs,
  lib,
}: let
  # Import test framework
  testFramework = import ./default.nix {inherit pkgs lib;};

  # Run a test and return structured result
  runTest = test: let
    result = testFramework.run test;
  in {
    name = result.name;
    passed = result.result.assertion;
    message = result.result.message;
  };
in {
  inherit runTest;
}
