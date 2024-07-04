args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.gparted feature.environment.systemPackages;
    expected = true;
  };
}
