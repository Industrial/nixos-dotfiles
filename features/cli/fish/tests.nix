{
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix {inherit inputs pkgs settings;};
in {
  test_environment_shells = {
    expr = builtins.elem pkgs.fish feature.environment.shells;
    expected = true;
  };

  # TODO: Test everything I configured in fish.
}
