args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.lxqt.qps feature.environment.systemPackages;
    expected = true;
  };
}
