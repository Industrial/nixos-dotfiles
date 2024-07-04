args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_xserver_enable = {
    expr = feature.services.xserver.enable;
    expected = true;
  };
  test_services_xserver_dpi = {
    expr = feature.services.xserver.dpi;
    expected = 96;
  };
  test_services_xserver_displayManager_lightdm_enable = {
    expr = feature.services.xserver.displayManager.lightdm.enable;
    expected = true;
  };
}
