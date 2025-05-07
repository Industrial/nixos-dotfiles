{pkgs ? import <nixpkgs> {}}:
pkgs.lib.runTests {
  # Test that devenv.nix evaluates
  testDevenvEvaluation = {
    expr = import ../devenv.nix {inherit pkgs;};
    expected = {
      # We expect it to be an attribute set
      __type = "attrs";
    };
  };

  # Test that common modules exist
  testCommonModules = {
    expr = builtins.pathExists ../common;
    expected = true;
  };

  # Test that hosts directory exists
  testHostsDirectory = {
    expr = builtins.pathExists ../hosts;
    expected = true;
  };
}
