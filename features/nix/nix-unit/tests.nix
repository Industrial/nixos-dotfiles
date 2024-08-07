args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.nix-unit feature.environment.systemPackages;
    expected = true;
  };
}
