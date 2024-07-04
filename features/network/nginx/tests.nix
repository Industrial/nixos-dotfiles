args @ {...}: let
  feature = import ./default.nix args;
in {
  test_enable = {
    expr = feature.services.nginx.enable;
    expected = true;
  };
  test_recommendedGzipSettings = {
    expr = feature.services.nginx.recommendedGzipSettings;
    expected = true;
  };
}
