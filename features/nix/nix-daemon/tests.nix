args @ {...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = feature.services.nix-daemon.enable;
    expected = true;
  };
}
