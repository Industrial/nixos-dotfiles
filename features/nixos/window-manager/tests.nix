args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_xserver_enable = {
    expr = feature.services.xserver.enable;
    expected = true;
  };
}
