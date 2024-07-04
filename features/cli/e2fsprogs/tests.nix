args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.e2fsprogs feature.environment.systemPackages;
    expected = true;
  };
}
