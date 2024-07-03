args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_environment_shells = {
    expr = builtins.elem pkgs.fish feature.environment.shells;
    expected = true;
  };

  # TODO: Test everything I configured in fish.
}
