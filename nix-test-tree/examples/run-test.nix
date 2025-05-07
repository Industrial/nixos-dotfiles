{
  pkgs,
  lib,
}: let
  runner = import ../runner.nix {inherit pkgs lib;};
  test = import ./basic-test.nix {inherit pkgs lib;};
  testExpr = builtins.toJSON (runner.runTest test);
in
  pkgs.writeScriptBin "run-test" ''
    #!${pkgs.bash}/bin/bash

    echo "Running minimal Nix Test Tree example..."

    # Get test result as JSON
    result='${testExpr}'

    # Extract values using jq
    name=$(echo "$result" | ${pkgs.jq}/bin/jq -r '.name')
    passed=$(echo "$result" | ${pkgs.jq}/bin/jq -r '.passed')
    message=$(echo "$result" | ${pkgs.jq}/bin/jq -r '.message')

    # Display result
    if [ "$passed" = "true" ]; then
      echo "PASS: $name"
    else
      echo "FAIL: $name"
      echo "  $message"
    fi
  ''
