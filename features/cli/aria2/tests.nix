args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.aria2 feature.environment.systemPackages;
    expected = true;
  };
}
