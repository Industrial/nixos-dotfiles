args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.dust feature.environment.systemPackages;
    expected = true;
  };
}
