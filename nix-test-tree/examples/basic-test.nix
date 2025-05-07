{
  pkgs,
  lib,
}: let
  testFramework = import ../default.nix {inherit pkgs lib;};
  runner = import ../runner.nix {inherit pkgs lib;};
in
  testFramework.it "should pass a basic equality test" (
    {assertions}:
      assertions.equal 1 1
  )
