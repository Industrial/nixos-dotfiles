let
  # Import Nixpkgs
  pkgs = import <nixpkgs> {};

  # Import nix-unit
  nixUnit = pkgs.nix-unit;

  # Get the list of test files
  testFiles = builtins.filter (path: builtins.match ".*test_.*\\.nix$" (builtins.toString path) != null) (pkgs.lib.filesystem.listFilesRecursive ./.);

  # Define a set of tests
  tests = builtins.listToAttrs (map (testFile: {
      name = builtins.baseNameOf testFile;
      value = import testFile;
    })
    testFiles);
in
  nixUnit.runTests tests
