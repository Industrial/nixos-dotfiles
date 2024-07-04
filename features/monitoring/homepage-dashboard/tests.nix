args @ {...}: let
  feature = import ./default.nix args;
in {
  # TODO: The rest of the settings need to be tested.
  test_services_homepage-dashboard_enable = {
    expr = feature.services.homepage-dashboard.enable;
    expected = true;
  };
}
