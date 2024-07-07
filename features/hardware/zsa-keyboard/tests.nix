args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_enable = {
    expr = feature.hardware.keyboard.zsa.enable;
    expected = true;
  };
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.wally-cli feature.environment.systemPackages;
    expected = true;
  };
}
