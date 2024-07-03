args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.p7zip feature.environment.systemPackages;
    expected = true;
  };
}
