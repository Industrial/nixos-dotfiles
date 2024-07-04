args @ {...}: let
  feature = import ./default.nix args;
in {
  test_enable = {
    expr = feature.services.invidious.enable;
    expected = true;
  };
  test_port = {
    expr = feature.services.invidious.port;
    expected = 4000;
  };
}
