args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.eza feature.environment.systemPackages;
    expected = true;
  };
}
