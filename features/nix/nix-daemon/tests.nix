args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = feature.services.nix-daemon.enable;
    expected = true;
  };
}
